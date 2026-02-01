# GStreamer 1.28.0 Components Summary

## Overview
This document summarizes key GStreamer 1.28.0 components for the instant replay system.

## Key Components

### 1. rtspsrc (RTSP Source)
**Purpose**: Receives RTSP streams and outputs RTP/RTCP packets.

**Key Properties**:
- `location`: RTSP URL (e.g., `rtsp://server:port/path`)
- `latency`: Buffer latency in milliseconds (default: 2000ms)
- `protocols`: Transport protocol selection (tcp, udp, udp-mcast)
- `buffer-mode`: How to buffer (none, slave, buffer, auto, synced)
- `ntp-sync`: Enable NTP synchronization for timing
- `ntp-time-source`: Use NTP or running time

**Important Notes**:
- Automatically creates dynamic pads for each stream
- Use `pad-added` signal to link dynamically
- Handles RTSP DESCRIBE, SETUP, PLAY, and TEARDOWN
- Supports authentication via `user-id` and `user-pw` properties

### 2. queue2 (Ring Buffer)
**Purpose**: Provides buffering with ring-buffer mode for time-shifting.

**Key Properties for Ring Buffer**:
- `ring-buffer-max-size`: Maximum size in bytes (0 = unlimited)
- `max-size-time`: Maximum buffer duration in nanoseconds (e.g., 60000000000 for 60s)
- `max-size-bytes`: Maximum size in bytes
- `max-size-buffers`: Maximum number of buffers
- `use-buffering`: Enable buffering messages
- `temp-template`: File template for disk buffering (NULL for memory only)

**Ring Buffer Mode**:
- Set `ring-buffer-max-size` to enable ring buffer behavior
- Old data automatically discarded when buffer fills
- Essential for live streaming with time-shift capabilities
- Use `max-size-time` for time-based buffering (recommended for replay)

**Important Notes**:
- For pure memory ring buffer: `temp-template=NULL`
- For disk-based: `temp-template=/tmp/replay-XXXXXX`
- Emits `buffering` messages for monitoring

### 3. nvdec/nvenc (NVIDIA Hardware Acceleration)
**Purpose**: GPU-accelerated H.264 decoding and encoding.

**nvdec (Decoder)**:
- Element name: `nvh264dec` or `nvdec`
- Properties:
  - `gpu-id`: Select GPU device (default: 0)
  - `cudacontext`: CUDA context for memory sharing
- Supports H.264, H.265, VP8, VP9, MPEG-2, MPEG-4
- Outputs raw video in GPU memory (NVMM or CUDA)

**nvenc (Encoder)**:
- Element name: `nvh264enc` or `nvenc`
- Key Properties:
  - `gpu-id`: Select GPU device
  - `bitrate`: Target bitrate in kbps
  - `preset`: Encoding preset (low-latency-hq, hq, default, low-latency, lossless)
  - `rc-mode`: Rate control (cbr, vbr, cqp)
  - `gop-size`: Keyframe interval
  - `zerolatency`: Enable zero-latency mode
- Accepts raw video in GPU memory or system memory

**Fallback Strategy**:
- Check for nvcodec plugin availability: `gst-inspect-1.0 nvh264dec`
- Fallback to software: `avdec_h264` (decode), `x264enc` (encode)
- On Intel/AMD: Use `vaapih264dec`/`vaapih264enc` (Linux) or `msdkh264dec`/`msdkh264enc`

### 4. gst-rtsp-server (RTSP Server Library)
**Purpose**: Serves media streams via RTSP with seeking support.

**Key Classes**:
- `GstRTSPServer`: Main server object
- `GstRTSPMountPoints`: Manages URL paths
- `GstRTSPMediaFactory`: Creates media pipelines for each client
- `GstRTSPMedia`: Individual media session

**Seeking Support**:
- Enable with: `gst_rtsp_media_factory_set_enable_rtcp(factory, TRUE)`
- Set: `gst_rtsp_media_factory_set_protocols(factory, GST_RTSP_LOWER_TRANS_TCP)`
- Use `appsrc` or `filesrc` with seekable sources
- For ring buffer: Must use time-based seeking

**Key Configuration**:
```c
GstRTSPMediaFactory *factory = gst_rtsp_media_factory_new();
gst_rtsp_media_factory_set_launch(factory, pipeline_string);
gst_rtsp_media_factory_set_shared(factory, TRUE); // Share pipeline
gst_rtsp_media_factory_set_enable_rtcp(factory, TRUE);
```

**Important Notes**:
- Shared pipelines reduce resource usage
- Each client connection creates a new session
- Supports RTSP commands: DESCRIBE, SETUP, PLAY, PAUSE, TEARDOWN, SEEK
- Seeking requires seekable source elements

## Cross-Platform Considerations

### Linux
- Install: `sudo apt-get install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev`
- Plugins: `gstreamer1.0-plugins-{good,bad,ugly} gstreamer1.0-libav gstreamer1.0-rtsp`
- NVIDIA: `gstreamer1.0-plugins-bad` (includes nvcodec since 1.18)
- Use pkg-config for compilation

### Windows
- Download MSI installer from gstreamer.freedesktop.org
- Install runtime + development packages
- Set `GSTREAMER_1_0_ROOT_MSVC_X86_64` environment variable
- Include directories and libraries in CMake

## Pipeline Design Pattern

### Basic Instant Replay Pipeline
```
rtspsrc location=rtsp://... 
  ! rtph264depay 
  ! h264parse 
  ! nvh264dec (or avdec_h264)
  ! queue2 max-size-time=60000000000 ring-buffer-max-size=1000000000
  ! nvh264enc (or x264enc)
  ! rtph264pay config-interval=1 
  ! udpsink (for RTP) or RTSP server
```

### Key Pipeline Considerations
1. **Depayload**: `rtph264depay` extracts H.264 from RTP packets
2. **Parse**: `h264parse` ensures proper stream format
3. **Decode** (optional): Decode if need to process/re-encode
4. **Ring Buffer**: `queue2` stores decoded or encoded data
5. **Encode**: Re-encode for output (adjust bitrate/quality)
6. **Payload**: `rtph264pay` packages H.264 into RTP
7. **Serve**: RTSP server or direct UDP sink

### Seeking Implementation
- Use `gst_element_seek()` on the pipeline
- Seek flags: `GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_KEY_UNIT`
- For ring buffer: Seek relative to buffer start time
- Monitor `GST_MESSAGE_SEGMENT_DONE` for completion

## Testing Commands

### Test RTSP Source
```bash
gst-launch-1.0 rtspsrc location=rtsp://your-stream ! \
  rtph264depay ! h264parse ! avdec_h264 ! videoconvert ! autovideosink
```

### Test Ring Buffer
```bash
gst-launch-1.0 videotestsrc ! \
  queue2 max-size-time=30000000000 ring-buffer-max-size=500000000 ! \
  autovideosink
```

### Test Hardware Acceleration
```bash
# NVIDIA
gst-launch-1.0 filesrc location=test.mp4 ! qtdemux ! h264parse ! \
  nvh264dec ! nvh264enc ! fakesink

# VAAPI (Intel/AMD)
gst-launch-1.0 filesrc location=test.mp4 ! qtdemux ! h264parse ! \
  vaapih264dec ! vaapih264enc ! fakesink
```

### Test RTSP Server
```bash
# Using test-launch from gst-rtsp-server examples
test-launch "( videotestsrc ! x264enc ! rtph264pay name=pay0 pt=96 )"
```

## Error Handling

### Plugin Checking
```c
GstRegistry *registry = gst_registry_get();
GstPlugin *plugin = gst_registry_find_plugin(registry, "nvcodec");
if (!plugin) {
    // Fallback to software
}
```

### State Change Monitoring
```c
GstStateChangeReturn ret = gst_element_set_state(pipeline, GST_STATE_PLAYING);
if (ret == GST_STATE_CHANGE_FAILURE) {
    // Handle error
}
```

### Bus Message Handling
- Monitor: `GST_MESSAGE_ERROR`, `GST_MESSAGE_WARNING`, `GST_MESSAGE_EOS`
- `GST_MESSAGE_BUFFERING`: Track buffer fill percentage
- `GST_MESSAGE_ELEMENT`: Custom element messages
