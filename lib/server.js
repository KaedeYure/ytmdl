#!/usr/bin/env node

const express = require('express');
const cors = require('cors');
const { exec, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const NodeID3 = require('node-id3');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');
const util = require('util');
const ytpl = require('@distube/ytpl');
const { Server } = require('socket.io');
const http = require('http');
const os = require('os');
const sharp = require('sharp');
const archiver = require('archiver');
const open = require('open');

const execPromise = util.promisify(exec);
const logger = createLogger();

// Initialize app and server
const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Setup middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(express.static(path.join(__dirname, 'views')));

// Directories setup
const TEMP_DIR = path.resolve(__dirname, '..', 'temp');
const BIN_DIR = path.resolve(__dirname, '..', 'bin');

// Function to ensure directory exists and is writable
function ensureDirectoryExists(dir) {
  try {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
      logger.info(`Created directory: ${dir}`);
    }
    
    // Verify the directory is writable by writing a test file
    const testFile = path.join(dir, '.test-write');
    fs.writeFileSync(testFile, 'test');
    fs.unlinkSync(testFile);
    
    logger.info(`Directory verified and writable: ${dir}`);
    return true;
  } catch (err) {
    logger.error(`Failed to ensure directory ${dir} exists and is writable:`, err);
    return false;
  }
}

// Setup and verify directories
[TEMP_DIR, BIN_DIR].forEach(dir => {
  if (!ensureDirectoryExists(dir)) {
    logger.error(`CRITICAL: Could not setup directory ${dir} - application may not function properly`);
  }
});

// Perform initial cleanup of temp directory
cleanupDirectory(TEMP_DIR)
  .then(count => {
    if (count > 0) {
      logger.info(`Initial cleanup: Removed ${count} existing files from temp directory`);
    }
  })
  .catch(err => {
    logger.error('Error during initial temp directory cleanup:', err);
  });

// File upload setup
const storage = multer.diskStorage({
  destination: TEMP_DIR,
  filename: (req, file, cb) => cb(null, uuidv4() + path.extname(file.originalname))
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB limit
});

// Helper functions
function createLogger() {
  return {
    info: (message, ...args) => console.log(`[INFO] ${message}`, ...args),
    warn: (message, ...args) => console.warn(`[WARN] ${message}`, ...args),
    error: (message, ...args) => console.error(`[ERROR] ${message}`, ...args),
    debug: (message, ...args) => console.log(`[DEBUG] ${message}`, ...args)
  };
}

function getFFmpegPath() {
  try {
    const platform = os.platform();
    const ffmpegCmd = platform === 'win32' ? 'where ffmpeg.exe' : 'which ffmpeg';
    
    const { stdout } = execSync(ffmpegCmd, { encoding: 'utf8' });
    const ffmpegPath = stdout.trim();
    
    if (ffmpegPath) {
      logger.info('Using system ffmpeg:', ffmpegPath);
      return ffmpegPath;
    }
  } catch (error) {
    logger.warn('System ffmpeg not found, trying ffmpeg-static');
  }
  
  try {
    const ffmpegStatic = require('ffmpeg-static');
    logger.info('Using ffmpeg-static:', ffmpegStatic);
    return ffmpegStatic;
  } catch (error) {
    logger.warn('ffmpeg-static not found:', error.message);
  }
  
  logger.error('No ffmpeg installation found. Please install ffmpeg or ffmpeg-static');
  return null;
}

function getYtDlpCommand() {
  const platform = os.platform();
  const ffmpegPath = getFFmpegPath();
  
  const ytdlpPath = path.join(BIN_DIR, platform === 'win32' ? 'yt-dlp.exe' : 'yt-dlp');
  const ytdlpExists = fs.existsSync(ytdlpPath);
  
  const baseCmd = ytdlpExists ? `"${ytdlpPath}"` : (platform === 'win32' ? 'yt-dlp.exe' : 'yt-dlp');
  
  if (ffmpegPath) {
    return `${baseCmd} --ffmpeg-location "${ffmpegPath}"`;
  }
  
  return baseCmd;
}

function cleanup(...filePaths) {
  // Log which files are being cleaned up
  logger.debug(`Attempting to clean up ${filePaths.length} files`);
  
  filePaths.forEach(file => {
    if (!file) return;
    
    try {
      // Handle absolute paths and resolve relative paths
      const fullPath = path.isAbsolute(file) ? file : path.resolve(file);
      
      if (fs.existsSync(fullPath)) {
        fs.unlinkSync(fullPath);
        logger.debug(`Deleted file: ${fullPath}`);
      }
      
      // Check for these common extensions and patterns
      const extensions = ['.part', '.webm', '.mp3', '.jpg', '.jpeg', '.temp'];
      const baseFile = fullPath.replace(/\.(mp3|webm|part|jpg|jpeg|temp)$/i, '');
      
      // Try to clean up all possible variations of the file
      extensions.forEach(ext => {
        const variantPath = `${baseFile}${ext}`;
        if (fs.existsSync(variantPath)) {
          fs.unlinkSync(variantPath);
          logger.debug(`Deleted variant file: ${variantPath}`);
        }
      });
      
      // Look for UUID-pattern files with the same base name
      const dirPath = path.dirname(fullPath);
      const fileBase = path.basename(fullPath).split('.')[0];
      
      if (/^[a-f0-9-]{36}$/i.test(fileBase)) {
        try {
          const dirFiles = fs.readdirSync(dirPath);
          const relatedFiles = dirFiles.filter(f => f.startsWith(fileBase) && f !== path.basename(fullPath));
          
          relatedFiles.forEach(relatedFile => {
            const relatedPath = path.join(dirPath, relatedFile);
            fs.unlinkSync(relatedPath);
            logger.debug(`Deleted related file with same UUID: ${relatedPath}`);
          });
        } catch (err) {
          logger.error(`Error cleaning up related files for ${fileBase}:`, err);
        }
      }
    } catch (err) {
      logger.error(`Failed to delete ${file}:`, err);
    }
  });
}

async function isPlaylist(url) {
  return ytpl.validateID(url);
}

async function getVideoMetadata(url) {
  let tempWebmFiles = [];
  try {
    // Check if URL contains playlist parameters and handle differently
    if (url.includes('list=') && !url.includes('&v=') && !url.includes('?v=')) {
      logger.info(`URL appears to be a playlist, using lighter metadata fetch for: ${url}`);
      // For playlists, use a more targeted command with less data
      const { stdout } = await execPromise(`${YT_DLP_CMD} --flat-playlist --dump-single-json "${url}"`, 
        { maxBuffer: 20 * 1024 * 1024, cwd: TEMP_DIR });
      const data = JSON.parse(stdout);
      
      // Handle playlist differently
      if (data.entries && data.entries.length > 0) {
        // Just get basic info from the first entry
        const firstEntry = data.entries[0];
        return {
          title: firstEntry.title || data.title || '',
          artist: '',
          album: data.title || '',
          thumbnail: firstEntry.thumbnail || data.thumbnail || '',
          url: firstEntry.url || url
        };
      }
    }
    
    // For single videos, use a more targeted approach to get only needed fields
    const tempId = uuidv4();
    const cmd = `${YT_DLP_CMD} --no-playlist --print-json -o "${tempId}.%(ext)s" -f bestaudio "${url}"`;
    logger.info(`Executing metadata command: ${cmd}`);
    
    // Increase maxBuffer to 20MB to handle larger metadata responses
    const { stdout } = await execPromise(cmd, { maxBuffer: 20 * 1024 * 1024, cwd: TEMP_DIR });
    
    // Find and track any webm files created with our temp ID
    const tempFiles = fs.readdirSync(TEMP_DIR);
    tempWebmFiles = tempFiles.filter(f => f.startsWith(tempId));
    
    const data = JSON.parse(stdout);
    const Artist = [...new Set(data.artists || [])].join(', ');
    const cleanArtistChannel = data.channel
      .replace(/ - Topic$/, '')
      .replace(/VEVO$/, '')
      .replace(/Official$/, '')
      .trim();

    let thumbnail = null;
    if (data.thumbnails && Array.isArray(data.thumbnails)) {
      const sortedThumbnails = data.thumbnails
        .filter(t => t.url)
        .sort((a, b) => {
          const aRes = (a.width || 0) * (a.height || 0);
          const bRes = (b.width || 0) * (b.height || 0);
          return bRes - aRes;
        });
      
      thumbnail = sortedThumbnails[0]?.url || data.thumbnail;
    } else {
      thumbnail = data.thumbnail;
    }

    return {
      title: data.title,
      artist: Artist || cleanArtistChannel,
      album: data.album || '',
      thumbnail,
      url: data.webpage_url || url
    };
  } catch (error) {
    logger.error('Error getting video metadata:', error);
    throw new Error(`Failed to get video metadata: ${error.message}`);
  } finally {
    // Clean up any temporary files created during metadata fetch
    if (tempWebmFiles.length > 0) {
      tempWebmFiles.forEach(file => {
        const filePath = path.join(TEMP_DIR, file);
        cleanup(filePath);
      });
    }
  }
}

async function getPlaylistMetadata(url) {
  try {
    const playlist = await ytpl(url);
    return playlist.items.map(item => ({
      url: item.shortUrl,
      title: item.title,
      thumbnail: item.thumbnail
    }));
  } catch (error) {
    logger.error('Error getting playlist metadata:', error);
    throw new Error(`Failed to get playlist metadata: ${error.message}`);
  }
}

async function downloadThumbnail(thumbnailUrl) {
  try {
    const response = await fetch(thumbnailUrl, {
      timeout: 10000,
      size: 10 * 1024 * 1024
    });

    if (!response.ok) throw new Error(`Failed to fetch thumbnail: ${response.status}`);

    const contentType = response.headers.get('content-type');
    if (!contentType || !contentType.includes('image/')) {
      throw new Error('Invalid image format');
    }

    const buffer = await response.arrayBuffer();
    const tempPath = path.join(TEMP_DIR, `${uuidv4()}.jpg`);

    await sharp(Buffer.from(buffer))
      .resize(800, 800, { fit: 'cover' })
      .jpeg({ quality: 90 })
      .toFile(tempPath);

    logger.debug(`Downloaded and processed thumbnail to ${tempPath}`);
    return tempPath;
  } catch (error) {
    logger.error('Thumbnail download failed:', error);
    return null;
  }
}

async function processVideo(url, title, artist, album, coverPath, socketId) {
  const outputId = uuidv4();
  // Use absolute paths with explicit temp directory
  const outputPath = path.resolve(TEMP_DIR, `${outputId}.mp3`);
  const tempWebmPath = path.resolve(TEMP_DIR, `${outputId}.webm`);
  const socket = io.to(socketId);
  
  logger.info(`Starting video processing: outputPath=${outputPath}, tempWebmPath=${tempWebmPath}`);
  
  try {
    socket.emit('progress', { status: 'downloading', title, progress: 0 });
    
    // Create command with all necessary options - adding more progress reporting
    const ytdlpOptions = [
      '-x',                         // Extract audio
      '--audio-format', 'mp3',      // Convert to mp3
      '--audio-quality', '0',       // Best quality
      '--no-check-certificate',     // Skip HTTPS certificate validation
      '--no-cache-dir',             // Don't use cache
      '--progress',                 // Show progress
      '--newline',                  // Show progress on new lines
      '--verbose',                  // Verbose output for more progress info
      '--no-part',                  // Don't use .part files
      '--no-mtime',                 // Don't use mtime
      '--restrict-filenames',       // Restrict filenames to ASCII characters
    ];
    
    // FIX: Properly escape paths and use absolute paths for output
    // Note the lack of quotes around the path - the path itself should not include quotes
    if (process.platform === 'win32') {
      ytdlpOptions.push('--output', tempWebmPath.replace(/\\/g, '/')); // Use forward slashes on Windows
    } else {
      ytdlpOptions.push('--output', tempWebmPath);
    }
    
    // Construct the full command
    const cmdBase = `${YT_DLP_CMD} ${ytdlpOptions.join(' ')} "${url}"`;
    logger.info(`Executing: ${cmdBase}`);
    
    const ytdlp = exec(cmdBase, { 
      maxBuffer: 10 * 1024 * 1024,  // Increase buffer to 10MB
      windowsHide: true,            // Hide command window on Windows
      cwd: TEMP_DIR                 // FIX: Force working directory to be the temp directory
    });
    
    // Collect output for better error reporting
    let stdoutData = '';
    let stderrData = '';
    let lastProgressUpdate = Date.now();
    const PROGRESS_UPDATE_INTERVAL = 250; // Update frontend every 250ms
    
    // Function to extract progress from output
    function extractAndEmitProgress(data) {
      // Look for different progress patterns
      const progressPatterns = [
        /\[download\]\s+([0-9.]+)%/, // Standard download progress
        /\[download\]\s+(\d+\.\d+)% of ~?(\d+\.\d+)(MiB|KiB)/, // Size-based progress
        /\[ffmpeg\]\s+(\d+)%/, // FFmpeg conversion progress
        /(\d+\.\d+)% of (\d+\.\d+)(MiB|KiB)/, // Generic percentage progress
        /frame=\s*(\d+).*?time=(\d+):(\d+):(\d+\.\d+)/ // FFmpeg frame progress
      ];
      
      let progress = null;
      
      // Try each pattern until we find a match
      for (const pattern of progressPatterns) {
        const match = data.match(pattern);
        if (match) {
          // For FFmpeg frame progress, calculate percentage based on time
          if (pattern.toString().includes('frame')) {
            const hours = parseInt(match[2]);
            const minutes = parseInt(match[3]);
            const seconds = parseFloat(match[4]);
            const totalSeconds = hours * 3600 + minutes * 60 + seconds;
            
            // Rough estimation assuming a 5-minute video (common for music)
            const estimatedDuration = 300; // 5 minutes in seconds
            progress = Math.min(99, (totalSeconds / estimatedDuration) * 100);
          } else {
            progress = parseFloat(match[1]);
          }
          break;
        }
      }
      
      // If we found progress info and enough time has passed since last update
      if (progress !== null) {
        const now = Date.now();
        if (now - lastProgressUpdate > PROGRESS_UPDATE_INTERVAL) {
          logger.debug(`Emitting progress: ${progress}%`);
          socket.emit('progress', { status: 'downloading', title, progress });
          lastProgressUpdate = now;
          
          // Also send intermediate stage messages based on progress
          if (progress > 90 && !downloadCompletedMessageSent) {
            socket.emit('progress', { 
              status: 'downloading', 
              title, 
              progress,
              message: 'Download almost complete, preparing to process...'
            });
            downloadCompletedMessageSent = true;
          } else if (progress > 50 && !halfwayMessageSent) {
            socket.emit('progress', { 
              status: 'downloading', 
              title, 
              progress,
              message: 'Download halfway complete...'
            });
            halfwayMessageSent = true;
          }
        }
      }
    }
    
    // Track message states
    let halfwayMessageSent = false;
    let downloadCompletedMessageSent = false;
    
    ytdlp.stdout.on('data', (data) => {
      stdoutData += data;
      const trimmedData = data.trim();
      logger.debug(`yt-dlp stdout: ${trimmedData}`);
      extractAndEmitProgress(trimmedData);
    });
    
    ytdlp.stderr.on('data', (data) => {
      stderrData += data;
      const trimmedData = data.trim();
      logger.debug(`yt-dlp stderr: ${trimmedData}`);
      extractAndEmitProgress(trimmedData);
    });

    // Progress update for ffmpeg conversion
    // Extract filename for ffmpeg progress tracking
    const filenameBase = path.basename(outputPath, '.mp3');
    
    // Split into chunks to track detailed conversion progress, emit intermediate progress updates
    function emitFakeProgress() {
      const progressIntervals = [
        { progress: 25, message: "Converting audio..." }, 
        { progress: 50, message: "Processing metadata..." }, 
        { progress: 75, message: "Finalizing..." }
      ];
      
      let intervalIndex = 0;
      const progressInterval = setInterval(() => {
        if (intervalIndex < progressIntervals.length) {
          const update = progressIntervals[intervalIndex];
          socket.emit('progress', { 
            status: 'processing', 
            title, 
            progress: update.progress,
            message: update.message
          });
          intervalIndex++;
        } else {
          clearInterval(progressInterval);
        }
      }, 700);
      
      // Clear interval if process completes
      ytdlp.on('close', () => clearInterval(progressInterval));
    }

    await new Promise((resolve, reject) => {
      ytdlp.on('close', code => {
        if (code === 0) {
          resolve();
        } else {
          logger.error(`Process failed with code ${code}`);
          logger.error(`STDOUT: ${stdoutData}`);
          logger.error(`STDERR: ${stderrData}`);
          reject(new Error(`Download process failed with code ${code}`));
        }
      });
    });

    // At this point, download is complete, show processing stages
    emitFakeProgress();
    
    socket.emit('progress', { status: 'processing', title, progress: 100 });

    // Check if file was actually created
    if (!fs.existsSync(outputPath)) {
      throw new Error('Output file was not created. The download might have failed silently.');
    }

    const tags = {
      title: title,
      artist: artist,
      album: album,
    };

    if (coverPath && fs.existsSync(coverPath)) {
      tags.image = {
        mime: 'image/jpeg',
        type: {
          id: 3,
          name: 'front cover',
        },
        description: 'cover',
        imageBuffer: fs.readFileSync(coverPath)
      };
    }

    NodeID3.write(tags, outputPath);

 if (fs.existsSync(tempWebmPath)) {
      try {
        fs.unlinkSync(tempWebmPath);
        logger.debug(`Deleted temporary webm file: ${tempWebmPath}`);
      } catch (err) {
        logger.error(`Failed to delete ${tempWebmPath}:`, err);
      }
    }
    
    logger.info(`Successfully processed video: ${title} -> ${outputPath}`);
    return outputPath;
  } catch (error) {
    logger.error(`Error processing video ${title}:`, error);
    // Make sure to cleanup both files in case of error
    cleanup(outputPath, tempWebmPath);
    throw error;
  }
}

async function sendFileInChunks(socket, filePath, filename) {
  const chunkSize = 1024 * 1024; // 1MB chunks
  const fileStream = fs.createReadStream(filePath, { highWaterMark: chunkSize });
  const fileStats = fs.statSync(filePath);
  let bytesSent = 0;

  logger.info(`Starting file transfer: ${filename} (${(fileStats.size / 1024 / 1024).toFixed(2)} MB)`);
  socket.emit('downloadStart', {
    filename,
    size: fileStats.size
  });

  for await (const chunk of fileStream) {
    bytesSent += chunk.length;
    const progress = (bytesSent / fileStats.size) * 100;
    
    await new Promise(resolve => {
      socket.emit('downloadChunk', { chunk, progress }, resolve);
    });
  }

  socket.emit('downloadComplete', { filename });
  logger.info(`File transfer complete: ${filename}`);
}

// Initialize YT-DLP command
const YT_DLP_CMD = getYtDlpCommand();

// Routes
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'views', 'index.html'));
});

app.post('/metadata', async (req, res) => {
  const { url } = req.body;
  
  try {
    logger.info(`Fetching metadata for: ${url}`);
    const isPlaylistUrl = await isPlaylist(url);
    
    if (isPlaylistUrl) {
      const playlistItems = await getPlaylistMetadata(url);
      logger.info(`Found playlist with ${playlistItems.length} items`);
      res.json({
        isPlaylist: true,
        items: playlistItems
      });
    } else {
      const metadata = await getVideoMetadata(url);
      logger.info(`Found single video: ${metadata.title}`);
      res.json({
        isPlaylist: false,
        items: [metadata]
      });
    }
  } catch (error) {
    logger.error('Metadata fetch error:', error);
    res.status(500).json({ error: 'Failed to fetch metadata' });
  }
});

app.post('/download', upload.fields([
  { name: 'cover', maxCount: 1 },
  { name: 'coverUrl', maxCount: 1 }
]), async (req, res) => {
  const { socketId, url, title, artist, album, isPlaylist } = req.body;
  let items = req.body.items;
  const results = [];
  const tempFiles = [];
  const socket = io.to(socketId);

  // Send immediate response to prevent timeout
  res.json({ success: true });
  logger.info(`Download request received - Socket ID: ${socketId}, URL: ${url}`);

  try {
    // Handle cover from file upload or URL
    let coverPath = req.files?.cover?.[0]?.path;
    
    // If cover URL was provided instead of file upload
    if (!coverPath && req.body.coverUrl) {
      try {
        logger.info(`Downloading cover from URL: ${req.body.coverUrl}`);
        coverPath = await downloadThumbnail(req.body.coverUrl);
        if (coverPath) tempFiles.push(coverPath);
      } catch (error) {
        logger.error('Error downloading cover from URL:', error);
      }
    }

    if (isPlaylist === 'true') {
      if (typeof items === 'string') {
        items = JSON.parse(items);
      }

      logger.info(`Processing playlist with ${items.length} items`);
      const zipPath = path.join(TEMP_DIR, `${uuidv4()}.zip`);
      const output = fs.createWriteStream(zipPath);
      const archive = archiver('zip', { zlib: { level: 9 } });
      
      socket.emit('progress', { status: 'start', total: items.length });

      output.on('close', async () => {
        try {
          logger.info(`Playlist archive complete: ${(archive.pointer() / 1024 / 1024).toFixed(2)} MB`);
          await sendFileInChunks(socket, zipPath, 'playlist.zip');
        } finally {
          cleanup(zipPath, ...tempFiles);
        }
      });

      archive.pipe(output);

      for (const [index, item] of items.entries()) {
        try {
          logger.info(`Processing playlist item ${index + 1}/${items.length}: ${item.title}`);
          let songArtist = artist;
          let songAlbum = album;
          let songCoverPath = coverPath;
          
          if (!songArtist || !songAlbum || !songCoverPath) {
            const metadata = await getVideoMetadata(item.url);
            songArtist = artist || metadata.artist;
            songAlbum = album || metadata.album;
            
            if (!songCoverPath && metadata.thumbnail) {
              songCoverPath = await downloadThumbnail(metadata.thumbnail);
              if (songCoverPath) tempFiles.push(songCoverPath);
            }
          }

          const outputPath = await processVideo(
            item.url,
            item.title,
            songArtist,
            songAlbum,
            songCoverPath,
            socketId
          );
          
          const safeFilename = `${item.title.replace(/[/\\?%*:|"<>]/g, '-')}.mp3`;
          archive.file(outputPath, { name: safeFilename });
          results.push(outputPath);
          
          socket.emit('progress', { 
            status: 'fileComplete', 
            current: index + 1, 
            total: items.length 
          });
          logger.info(`Added to archive: ${safeFilename}`);
        } catch (error) {
          logger.error(`Error processing ${item.title}:`, error);
          socket.emit('progress', { 
            status: 'error', 
            title: item.title, 
            error: error.message 
          });
        }
      }

      archive.finalize();
    } else {
      logger.info(`Processing single video: ${title}`);
      if (!coverPath) {
        try {
          const metadata = await getVideoMetadata(url);
          if (metadata.thumbnail) {
            logger.info(`Downloading thumbnail for ${title}`);
            coverPath = await downloadThumbnail(metadata.thumbnail);
            if (coverPath) tempFiles.push(coverPath);
          }
        } catch (error) {
          logger.error('Error downloading thumbnail:', error);
        }
      }

      try {
        const outputPath = await processVideo(url, title, artist, album, coverPath, socketId);
        const safeFilename = `${title.replace(/[/\\?%*:|"<>]/g, '-')}.mp3`;
        await sendFileInChunks(socket, outputPath, safeFilename);
        cleanup(outputPath, coverPath, ...tempFiles);
      } catch (error) {
        logger.error('Error processing single video:', error);
        socket.emit('error', { message: error.message || 'Failed to process video' });
        cleanup(...tempFiles, coverPath);
      }
    }
  } catch (error) {
    logger.error('Download error:', error);
    socket.emit('error', { message: 'Download failed: ' + (error.message || 'Unknown error') });
    cleanup(...results, ...tempFiles, req.files?.cover?.[0]?.path);
  }
});

const CLEANUP_INTERVAL = 15 * 60 * 1000; // Run every 15 minutes

// Function to recursively clean a directory of temp files
function cleanupDirectory(dir, isRecursive = false) {
  return new Promise((resolve) => {
    fs.readdir(dir, { withFileTypes: true }, (err, entries) => {
      if (err) {
        logger.error(`Error reading directory ${dir}:`, err);
        return resolve(0);
      }
      
      let cleaned = 0;
      let pending = entries.length;
      
      // If no files to process, resolve immediately
      if (pending === 0) return resolve(0);
      
      entries.forEach(entry => {
        const entryPath = path.join(dir, entry.name);
        
        // If it's a directory and we want recursive cleanup
        if (entry.isDirectory() && isRecursive) {
          cleanupDirectory(entryPath, true)
            .then(count => {
              cleaned += count;
              if (--pending === 0) resolve(cleaned);
            });
          return;
        }
        
        // Skip directories if not recursive
        if (entry.isDirectory()) {
          if (--pending === 0) resolve(cleaned);
          return;
        }
        
        // Process files
        fs.stat(entryPath, (err, stats) => {
          if (err) {
            if (--pending === 0) resolve(cleaned);
            return;
          }
          
          const now = Date.now();
          const fileAge = now - stats.mtime.getTime();
          const MAX_AGE = 2 * 60 * 60 * 1000; // 2 hours
          
          // Check if the file matches temporary file patterns or is old enough
          const isTempFile = 
            entry.name.endsWith('.webm') || 
            entry.name.endsWith('.part') || 
            entry.name.endsWith('.temp') ||
            entry.name.match(/^[a-f0-9-]{36}\.(webm|mp3|part|jpg|jpeg)$/i);
          
          if (isTempFile || fileAge > MAX_AGE) {
            fs.unlink(entryPath, err => {
              if (err) {
                logger.error(`Failed to delete ${entryPath}:`, err);
              } else {
                cleaned++;
                logger.debug(`Cleanup: Removed ${entryPath}`);
              }
              
              if (--pending === 0) resolve(cleaned);
            });
          } else {
            if (--pending === 0) resolve(cleaned);
          }
        });
      });
    });
  });
}

// Export server start function
function start() {
    return new Promise((resolve) => {
        // Set up the cleanup interval
        const cleanupInterval = setInterval(async () => {
            logger.info('Starting scheduled cleanup...');
            
            // Paths to clean
            const pathsToClean = [
              TEMP_DIR,                  // Main temp directory
              __dirname,                 // Current directory
              path.join(__dirname, '..') // Parent directory
            ];
            
            let totalCleaned = 0;
            
            // Process each path
            for (const dirPath of pathsToClean) {
              try {
                const cleaned = await cleanupDirectory(dirPath);
                totalCleaned += cleaned;
                
                if (cleaned > 0) {
                  logger.info(`Cleanup: Removed ${cleaned} old files from ${dirPath}`);
                }
              } catch (err) {
                logger.error(`Error during cleanup of ${dirPath}:`, err);
              }
            }
            
            if (totalCleaned > 0) {
              logger.info(`Cleanup completed: Removed a total of ${totalCleaned} files`);
            } else {
              logger.debug('Cleanup completed: No files needed removal');
            }
        }, CLEANUP_INTERVAL);

        // Ensure cleanup interval is cleared when the process exits
        process.on('exit', () => {
            clearInterval(cleanupInterval);
            logger.info('Cleanup interval cleared on exit');
        });

        // Start server
        const PORT = process.env.PORT || 9862;
        server.listen(PORT, () => {
            const url = `http://localhost:${PORT}`;
            logger.info(`Server running on port ${PORT}`);
            logger.info(`Using yt-dlp command: ${YT_DLP_CMD}`);
            
            // Open in default browser
            open.default(url).catch(err => {
                logger.warn('Failed to open browser:', err.message);
            });
            
            resolve(server);  // Resolve the promise when server starts
        });
    });
}

start();