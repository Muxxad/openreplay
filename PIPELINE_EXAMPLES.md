# GStreamer Pipeline Examples and Test Commands

This file contains various `gst-launch-1.0` command examples for testing the instant replay pipeline components.

## Basic Component Tests

### 1. Test Video Test Source
```bash
# Display test pattern for 5 seconds
gst-launch-1.0 videotestsrc ! autovideosink

# Specific resolution and framerate
gst-launch-1.0 videotestsrc ! \
    video/x-raw,width=1920,height=1080,framerate=30/1 ! \
    autovideosink
```

### 2. Test RTSP Source
```bash
# Basic RTSP source test (replace with your stream URL)
gst-launch-1.0 rtspsrc location=rtsp://192.168.1.100:554/stream ! \
    rtph264depay ! h264parse ! avdec_h264 ! \
    videoconvert ! autovideosink

# With TCP transport (more reliable)
gst-launch-1.0 rtspsrc location=rtsp://camera:554/stream protocols=tcp ! \
    rtph264depay ! h264parse ! avdec_h264 ! autovideosink

# With specific latency
gst-launch-1.0 rtspsrc location=rtsp://camera:554/stream latency=100 ! \
    rtph264depay ! h264parse ! avdec_h264 ! autovideosink
```

### 3. Test RTSP Authentication
```bash
# RTSP with username/password
gst-launch-1.0 rtspsrc location=rtsp://camera:554/stream \
    user-id=admin user-pw=password ! \
    rtph264depay ! h264parse ! avdec_h264 ! autovideosink
```

## Hardware Acceleration Tests

### 4. NVIDIA nvcodec Test
```bash
# Test NVIDIA decoder
gst-launch-1.0 filesrc location=test.mp4 ! qtdemux ! h264parse ! \
    nvh264dec ! autovideosink

# Test NVIDIA encoder
gst-launch-1.0 videotestsrc num-buffers=300 ! \
    nvh264enc bitrate=4000 ! h264parse ! \
    mp4mux ! filesink location=output_nvidia.mp4

# Complete NVIDIA transcode
gst-launch-1.0 filesrc location=input.mp4 ! qtdemux ! h264parse ! \
    nvh264dec ! nvh264enc bitrate=2000 preset=low-latency-hq ! \
    h264parse ! mp4mux ! filesink location=output.mp4

# RTSP with NVIDIA acceleration
gst-launch-1.0 rtspsrc location=rtsp://camera:554/stream ! \
    rtph264depay ! h264parse ! nvh264dec ! nvh264enc ! \
    h264parse ! rtph264pay ! udpsink host=localhost port=5000
```

### 5. VAAPI (Intel/AMD) Test
```bash
# Test VAAPI decoder
gst-launch-1.0 filesrc location=test.mp4 ! qtdemux ! h264parse ! \
    vaapih264dec ! vaapisink

# Test VAAPI encoder
gst-launch-1.0 videotestsrc num-buffers=300 ! \
    vaapih264enc bitrate=4000 ! h264parse ! \
    mp4mux ! filesink location=output_vaapi.mp4

# Complete VAAPI transcode
gst-launch-1.0 filesrc location=input.mp4 ! qtdemux ! h264parse ! \
    vaapih264dec ! vaapih264enc bitrate=2000 ! \
    h264parse ! mp4mux ! filesink location=output.mp4
```

### 6. Software Codec Test
```bash
# Software decode
gst-launch-1.0 filesrc location=test.mp4 ! qtdemux ! h264parse ! \
    avdec_h264 ! autovideosink

# Software encode with x264
gst-launch-1.0 videotestsrc num-buffers=300 ! \
    x264enc bitrate=4000 tune=zerolatency ! h264parse ! \
    mp4mux ! filesink location=output_x264.mp4
```

## Ring Buffer Tests

### 7. Test queue2 Ring Buffer (Memory-based)
```bash
# 30-second ring buffer in memory
gst-launch-1.0 videotestsrc is-live=true ! \
    x264enc tune=zerolatency ! h264parse ! \
    queue2 max-size-time=30000000000 ring-buffer-max-size=500000000 \
        use-buffering=true temp-template=NULL ! \
    avdec_h264 ! autovideosink

# Monitor buffering percentage
GST_DEBUG=queue2:5 gst-launch-1.0 videotestsrc is-live=true ! \
    x264enc ! h264parse ! \
    queue2 max-size-time=10000000000 ring-buffer-max-size=200000000 \
        use-buffering=true ! \
    avdec_h264 ! autovideosink
```

### 8. Test queue2 Ring Buffer (Disk-based)
```bash
# 60-second ring buffer on disk
gst-launch-1.0 videotestsrc is-live=true ! \
    x264enc tune=zerolatency ! h264parse ! \
    queue2 max-size-time=60000000000 ring-buffer-max-size=1000000000 \
        use-buffering=true temp-template=/tmp/gst-buffer-XXXXXX ! \
    filesink location=/tmp/output.h264

# Check created buffer files
ls -lh /tmp/gst-buffer-*
```

### 9. Ring Buffer with RTSP Input
```bash
# RTSP source with ring buffer
gst-launch-1.0 rtspsrc location=rtsp://camera:554/stream ! \
    rtph264depay ! h264parse ! \
    queue2 max-size-time=60000000000 ring-buffer-max-size=1000000000 ! \
    avdec_h264 ! autovideosink

# Save to file instead
gst-launch-1.0 rtspsrc location=rtsp://camera:554/stream ! \
    rtph264depay ! h264parse ! \
    queue2 max-size-time=60000000000 ring-buffer-max-size=1000000000 ! \
    filesink location=/tmp/replay-buffer.h264
```

## RTP/RTSP Tests

### 10. RTP Streaming (Sender)
```bash
# Send H.264 over RTP to localhost:5000
gst-launch-1.0 videotestsrc is-live=true ! \
    x264enc tune=zerolatency bitrate=2000 ! \
    h264parse ! rtph264pay config-interval=1 pt=96 ! \
    udpsink host=127.0.0.1 port=5000

# Send from RTSP source
gst-launch-1.0 rtspsrc location=rtsp://camera:554/stream ! \
    rtph264depay ! h264parse ! \
    rtph264pay config-interval=1 ! \
    udpsink host=127.0.0.1 port=5000
```

### 11. RTP Streaming (Receiver)
```bash
# Receive H.264 from RTP
gst-launch-1.0 udpsrc port=5000 caps="application/x-rtp,media=video,\
    clock-rate=90000,encoding-name=H264,payload=96" ! \
    rtph264depay ! h264parse ! avdec_h264 ! autovideosink

# Save received stream to file
gst-launch-1.0 udpsrc port=5000 caps="application/x-rtp,media=video,\
    clock-rate=90000,encoding-name=H264,payload=96" ! \
    rtph264depay ! h264parse ! filesink location=/tmp/received.h264
```

### 12. RTSP Server Test (requires gst-rtsp-server tools)
```bash
# Simple RTSP server with test pattern
gst-rtsp-server-launch "( videotestsrc is-live=true ! \
    x264enc tune=zerolatency ! rtph264pay name=pay0 pt=96 )"

# RTSP server from file
gst-rtsp-server-launch "( filesrc location=video.mp4 ! qtdemux ! \
    h264parse ! rtph264pay name=pay0 pt=96 )"

# RTSP server with NVIDIA encoding
gst-rtsp-server-launch "( videotestsrc is-live=true ! \
    nvh264enc bitrate=4000 ! rtph264pay name=pay0 pt=96 )"
```

## Complete Pipeline Tests

### 13. End-to-End Test (Software)
```bash
# Complete pipeline: test source → encode → ring buffer → decode → display
gst-launch-1.0 \
    videotestsrc is-live=true pattern=ball ! \
    video/x-raw,width=1920,height=1080,framerate=30/1 ! \
    x264enc tune=zerolatency bitrate=4000 ! \
    h264parse ! \
    queue2 max-size-time=30000000000 ring-buffer-max-size=500000000 ! \
    avdec_h264 ! \
    videoconvert ! autovideosink
```

### 14. End-to-End Test (NVIDIA)
```bash
# Complete pipeline with NVIDIA acceleration
gst-launch-1.0 \
    videotestsrc is-live=true ! \
    video/x-raw,width=1920,height=1080,framerate=30/1 ! \
    nvh264enc bitrate=4000 preset=low-latency-hq ! \
    h264parse ! \
    queue2 max-size-time=30000000000 ring-buffer-max-size=500000000 ! \
    nvh264dec ! \
    autovideosink
```

### 15. RTSP Input to File (Instant Replay Recording)
```bash
# Record 60-second rolling buffer from RTSP camera
gst-launch-1.0 \
    rtspsrc location=rtsp://192.168.1.100:554/stream latency=200 ! \
    rtph264depay ! \
    h264parse ! \
    queue2 max-size-time=60000000000 ring-buffer-max-size=1000000000 \
        temp-template=/tmp/replay-XXXXXX ! \
    filesink location=/tmp/instant-replay.h264

# To play back:
gst-launch-1.0 filesrc location=/tmp/instant-replay.h264 ! \
    h264parse ! avdec_h264 ! autovideosink
```

### 16. RTSP Input → Ring Buffer → RTP Output
```bash
# Instant replay: RTSP in → buffer → RTP out
gst-launch-1.0 \
    rtspsrc location=rtsp://camera:554/stream ! \
    rtph264depay ! h264parse ! \
    queue2 max-size-time=60000000000 ring-buffer-max-size=1000000000 ! \
    rtph264pay config-interval=1 pt=96 ! \
    udpsink host=127.0.0.1 port=5000

# Connect with receiver:
gst-launch-1.0 udpsrc port=5000 \
    caps="application/x-rtp,media=video,clock-rate=90000,\
          encoding-name=H264,payload=96" ! \
    rtph264depay ! h264parse ! avdec_h264 ! autovideosink
```

### 17. Multi-Client RTSP with Seeking
```bash
# This requires the full application or gst-rtsp-server library
# Example client access:

# Client 1 (VLC)
vlc rtsp://localhost:8554/replay

# Client 2 (ffplay with seeking)
ffplay -rtsp_transport tcp rtsp://localhost:8554/replay

# Client 3 (GStreamer with seeking)
gst-launch-1.0 playbin uri=rtsp://localhost:8554/replay
```

## Debugging and Analysis

### 18. Pipeline Debugging
```bash
# Enable debug logging (level 3 = info)
GST_DEBUG=3 gst-launch-1.0 rtspsrc location=rtsp://... ! fakesink

# Debug specific elements (level 5 = debug)
GST_DEBUG=rtspsrc:5,queue2:5 gst-launch-1.0 ...

# Show all messages
GST_DEBUG=*:3 gst-launch-1.0 ...

# Save debug to file
GST_DEBUG=*:3 GST_DEBUG_FILE=/tmp/gst-debug.log gst-launch-1.0 ...
```

### 19. Pipeline Graph Visualization
```bash
# Generate DOT graph files
GST_DEBUG_DUMP_DOT_DIR=/tmp gst-launch-1.0 videotestsrc ! autovideosink

# Convert to PNG (requires graphviz)
dot -Tpng /tmp/*.dot -o pipeline.png
```

### 20. Performance Analysis
```bash
# Show FPS with fpsdisplaysink
gst-launch-1.0 videotestsrc ! \
    x264enc ! avdec_h264 ! \
    fpsdisplaysink video-sink=autovideosink text-overlay=true

# Monitor CPU and bandwidth
gst-launch-1.0 rtspsrc location=rtsp://camera:554/stream ! \
    rtph264depay ! h264parse ! avdec_h264 ! \
    fpsdisplaysink video-sink=autovideosink text-overlay=true
```

## Seeking Tests

### 21. File Seeking
```bash
# Play file with seeking capability (use space to pause, arrows to seek)
gst-launch-1.0 playbin uri=file:///path/to/video.mp4

# Seek to specific time (10 seconds)
gst-launch-1.0 filesrc location=video.mp4 ! qtdemux ! h264parse ! \
    avdec_h264 ! autovideosink
# Then send seek event with gst-launch (limited in CLI)
```

### 22. RTSP Seeking
```bash
# Use ffmpeg to seek in RTSP stream
ffmpeg -rtsp_transport tcp -i rtsp://localhost:8554/replay \
    -ss 00:00:10 -t 00:00:05 -c copy output.mp4

# Extract 5 seconds starting from 10 seconds into buffer
```

## Bitrate and Quality Tests

### 23. Different Bitrates
```bash
# Low bitrate (1 Mbps)
gst-launch-1.0 videotestsrc ! x264enc bitrate=1000 ! \
    h264parse ! mp4mux ! filesink location=low.mp4

# Medium bitrate (4 Mbps)
gst-launch-1.0 videotestsrc ! x264enc bitrate=4000 ! \
    h264parse ! mp4mux ! filesink location=medium.mp4

# High bitrate (8 Mbps)
gst-launch-1.0 videotestsrc ! x264enc bitrate=8000 ! \
    h264parse ! mp4mux ! filesink location=high.mp4
```

### 24. Encoder Presets
```bash
# x264 ultrafast (lowest CPU, lower quality)
gst-launch-1.0 videotestsrc ! \
    x264enc speed-preset=ultrafast tune=zerolatency ! \
    h264parse ! mp4mux ! filesink location=ultrafast.mp4

# x264 medium (balanced)
gst-launch-1.0 videotestsrc ! \
    x264enc speed-preset=medium ! \
    h264parse ! mp4mux ! filesink location=medium.mp4

# NVIDIA preset for low latency
gst-launch-1.0 videotestsrc ! \
    nvh264enc preset=low-latency-hq rc-mode=cbr bitrate=4000 ! \
    h264parse ! mp4mux ! filesink location=nvidia_ll.mp4
```

## Stress Tests

### 25. High Resolution Test
```bash
# 4K video pipeline
gst-launch-1.0 videotestsrc ! \
    video/x-raw,width=3840,height=2160,framerate=30/1 ! \
    nvh264enc bitrate=20000 ! h264parse ! \
    queue2 max-size-time=30000000000 ! \
    nvh264dec ! autovideosink
```

### 26. Multiple Stream Test
```bash
# Terminal 1: Stream 1
gst-launch-1.0 videotestsrc pattern=0 ! \
    x264enc ! rtph264pay ! udpsink port=5000

# Terminal 2: Stream 2
gst-launch-1.0 videotestsrc pattern=1 ! \
    x264enc ! rtph264pay ! udpsink port=5001

# Terminal 3: Receive stream 1
gst-launch-1.0 udpsrc port=5000 caps="application/x-rtp" ! \
    rtph264depay ! avdec_h264 ! autovideosink

# Terminal 4: Receive stream 2
gst-launch-1.0 udpsrc port=5001 caps="application/x-rtp" ! \
    rtph264depay ! avdec_h264 ! autovideosink
```

## Notes

- Replace `rtsp://camera:554/stream` with your actual RTSP URL
- Use `GST_DEBUG=level` for troubleshooting (levels: 0-9)
- Add `sync=false` to sinks for lower latency: `autovideosink sync=false`
- Use `Ctrl+C` to stop pipelines
- For Windows, use `gst-launch-1.0.exe` instead of `gst-launch-1.0`
- Ring buffer size: 1GB ≈ 8-10 minutes of 1080p H.264 at 2 Mbps

## Common Issues

1. **"No element named X"**: Install missing plugin package
2. **High latency**: Use `tune=zerolatency`, reduce `latency` property
3. **Stuttering**: Increase `max-size-time` on queue2
4. **No video**: Check caps negotiation with `GST_DEBUG=*:5`
5. **RTSP timeout**: Try `protocols=tcp` on rtspsrc
