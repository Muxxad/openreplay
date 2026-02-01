#!/bin/bash
# GStreamer Pipeline Test Script
# Tests various components before running the full application

set -e

echo "=================================="
echo "GStreamer Instant Replay Test Suite"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
test_passed() {
    echo -e "${GREEN}✓ PASSED${NC}: $1"
    ((TESTS_PASSED++))
}

test_failed() {
    echo -e "${RED}✗ FAILED${NC}: $1"
    ((TESTS_FAILED++))
}

test_warning() {
    echo -e "${YELLOW}⚠ WARNING${NC}: $1"
}

# Check if gst-launch-1.0 exists
if ! command -v gst-launch-1.0 &> /dev/null; then
    echo "ERROR: gst-launch-1.0 not found. Please install GStreamer."
    exit 1
fi

echo "GStreamer version:"
gst-launch-1.0 --version
echo ""

# 1. Test basic pipeline
echo "=== Test 1: Basic videotestsrc pipeline ==="
if gst-launch-1.0 videotestsrc num-buffers=30 ! autovideosink 2>&1 | grep -q "Setting pipeline"; then
    test_passed "Basic pipeline creation"
else
    test_failed "Basic pipeline creation"
fi
echo ""

# 2. Test RTSP elements
echo "=== Test 2: Check RTSP elements ==="
if gst-inspect-1.0 rtspsrc &> /dev/null; then
    test_passed "rtspsrc element available"
else
    test_failed "rtspsrc element missing"
fi

if gst-inspect-1.0 rtph264depay &> /dev/null; then
    test_passed "rtph264depay element available"
else
    test_failed "rtph264depay element missing"
fi

if gst-inspect-1.0 rtph264pay &> /dev/null; then
    test_passed "rtph264pay element available"
else
    test_failed "rtph264pay element missing"
fi
echo ""

# 3. Test H.264 parser
echo "=== Test 3: Check H.264 parser ==="
if gst-inspect-1.0 h264parse &> /dev/null; then
    test_passed "h264parse element available"
else
    test_failed "h264parse element missing"
fi
echo ""

# 4. Test queue2
echo "=== Test 4: Test queue2 ring buffer ==="
echo "Testing queue2 with ring buffer mode (5 seconds)..."
if timeout 3s gst-launch-1.0 videotestsrc ! \
    queue2 max-size-time=5000000000 ring-buffer-max-size=100000000 ! \
    fakesink 2>&1 | grep -q "Setting pipeline"; then
    test_passed "queue2 ring buffer configuration"
else
    test_failed "queue2 ring buffer configuration"
fi
echo ""

# 5. Test hardware acceleration - NVIDIA
echo "=== Test 5: Check NVIDIA nvcodec ==="
if gst-inspect-1.0 nvh264dec &> /dev/null; then
    test_passed "NVIDIA nvh264dec available"
    
    if gst-inspect-1.0 nvh264enc &> /dev/null; then
        test_passed "NVIDIA nvh264enc available"
    else
        test_warning "nvh264enc not found"
    fi
else
    test_warning "NVIDIA nvcodec not available (normal if no NVIDIA GPU)"
fi
echo ""

# 6. Test hardware acceleration - VAAPI
echo "=== Test 6: Check VAAPI (Intel/AMD) ==="
if gst-inspect-1.0 vaapih264dec &> /dev/null; then
    test_passed "VAAPI vaapih264dec available"
    
    if gst-inspect-1.0 vaapih264enc &> /dev/null; then
        test_passed "VAAPI vaapih264enc available"
    else
        test_warning "vaapih264enc not found"
    fi
else
    test_warning "VAAPI not available (normal if no Intel/AMD GPU)"
fi
echo ""

# 7. Test software codecs
echo "=== Test 7: Check software codecs ==="
if gst-inspect-1.0 avdec_h264 &> /dev/null; then
    test_passed "Software decoder (avdec_h264) available"
else
    test_failed "Software decoder missing - install gstreamer1.0-libav"
fi

if gst-inspect-1.0 x264enc &> /dev/null; then
    test_passed "Software encoder (x264enc) available"
else
    test_failed "Software encoder missing - install gstreamer1.0-plugins-ugly"
fi
echo ""

# 8. Test H.264 encoding/decoding pipeline
echo "=== Test 8: Test H.264 encode/decode pipeline ==="
echo "Creating test H.264 file..."
if gst-launch-1.0 videotestsrc num-buffers=100 ! \
    x264enc ! h264parse ! filesink location=/tmp/test_gst.h264 2>&1 | grep -q "Setting pipeline"; then
    test_passed "H.264 encoding to file"
    
    echo "Testing H.264 decoding..."
    if timeout 3s gst-launch-1.0 filesrc location=/tmp/test_gst.h264 ! \
        h264parse ! avdec_h264 ! fakesink 2>&1 | grep -q "Setting pipeline"; then
        test_passed "H.264 decoding from file"
    else
        test_failed "H.264 decoding from file"
    fi
    
    rm -f /tmp/test_gst.h264
else
    test_failed "H.264 encoding to file"
fi
echo ""

# 9. Test RTP payload/depayload
echo "=== Test 9: Test RTP H.264 payload/depayload ==="
echo "Creating RTP H.264 pipeline..."
if timeout 3s gst-launch-1.0 videotestsrc num-buffers=100 ! \
    x264enc ! h264parse ! rtph264pay ! rtph264depay ! \
    h264parse ! avdec_h264 ! fakesink 2>&1 | grep -q "Setting pipeline"; then
    test_passed "RTP H.264 payload/depayload"
else
    test_failed "RTP H.264 payload/depayload"
fi
echo ""

# 10. Test complete pipeline (without RTSP source)
echo "=== Test 10: Test complete pipeline simulation ==="
echo "Simulating complete instant replay pipeline..."
if timeout 5s gst-launch-1.0 videotestsrc is-live=true ! \
    video/x-raw,width=640,height=480,framerate=30/1 ! \
    x264enc tune=zerolatency bitrate=2000 ! \
    h264parse ! \
    queue2 max-size-time=10000000000 ring-buffer-max-size=200000000 ! \
    avdec_h264 ! \
    x264enc bitrate=2000 ! \
    h264parse ! \
    fakesink 2>&1 | grep -q "Setting pipeline"; then
    test_passed "Complete pipeline simulation"
else
    test_failed "Complete pipeline simulation"
fi
echo ""

# Summary
echo "=================================="
echo "Test Summary"
echo "=================================="
echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All critical tests passed! Ready to build application.${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please install missing plugins:${NC}"
    echo "  Ubuntu/Debian:"
    echo "    sudo apt-get install gstreamer1.0-plugins-{base,good,bad,ugly} gstreamer1.0-libav"
    echo ""
    exit 1
fi
