cmake_minimum_required(VERSION 3.15)
project(gstreamer-instant-replay VERSION 1.0.0 LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Platform detection
if(WIN32)
    set(PLATFORM_WINDOWS TRUE)
    message(STATUS "Building for Windows")
elseif(UNIX AND NOT APPLE)
    set(PLATFORM_LINUX TRUE)
    message(STATUS "Building for Linux")
elseif(APPLE)
    set(PLATFORM_MACOS TRUE)
    message(STATUS "Building for macOS")
endif()

# Find GStreamer packages
if(PLATFORM_WINDOWS)
    # Windows: Use GSTREAMER_1_0_ROOT_MSVC_X86_64 environment variable
    if(DEFINED ENV{GSTREAMER_1_0_ROOT_MSVC_X86_64})
        set(GSTREAMER_ROOT $ENV{GSTREAMER_1_0_ROOT_MSVC_X86_64})
        message(STATUS "GStreamer root: ${GSTREAMER_ROOT}")
        
        # Set paths manually for Windows
        set(GSTREAMER_INCLUDE_DIRS
            "${GSTREAMER_ROOT}/include/gstreamer-1.0"
            "${GSTREAMER_ROOT}/include/glib-2.0"
            "${GSTREAMER_ROOT}/lib/glib-2.0/include"
        )
        
        set(GSTREAMER_LIBRARY_DIRS
            "${GSTREAMER_ROOT}/lib"
        )
        
        # Libraries
        set(GSTREAMER_LIBRARIES
            gstreamer-1.0
            gstrtspserver-1.0
            gobject-2.0
            glib-2.0
            gstrtsp-1.0
            gstsdp-1.0
            gstapp-1.0
        )
        
        # Add library directories
        link_directories(${GSTREAMER_LIBRARY_DIRS})
        
    else()
        message(FATAL_ERROR 
            "GSTREAMER_1_0_ROOT_MSVC_X86_64 environment variable not set.\n"
            "Please install GStreamer 1.28.0 MSVC runtime and development installers.\n"
            "Download from: https://gstreamer.freedesktop.org/download/")
    endif()
    
else()
    # Linux/macOS: Use pkg-config
    find_package(PkgConfig REQUIRED)
    
    # GStreamer 1.0
    pkg_check_modules(GSTREAMER REQUIRED gstreamer-1.0>=1.28.0)
    pkg_check_modules(GSTREAMER_RTSP_SERVER REQUIRED gstreamer-rtsp-server-1.0>=1.28.0)
    pkg_check_modules(GSTREAMER_RTSP REQUIRED gstreamer-rtsp-1.0>=1.28.0)
    pkg_check_modules(GSTREAMER_SDP REQUIRED gstreamer-sdp-1.0>=1.28.0)
    pkg_check_modules(GSTREAMER_APP REQUIRED gstreamer-app-1.0>=1.28.0)
    
    # Combine all include directories
    set(GSTREAMER_INCLUDE_DIRS
        ${GSTREAMER_INCLUDE_DIRS}
        ${GSTREAMER_RTSP_SERVER_INCLUDE_DIRS}
        ${GSTREAMER_RTSP_INCLUDE_DIRS}
        ${GSTREAMER_SDP_INCLUDE_DIRS}
        ${GSTREAMER_APP_INCLUDE_DIRS}
    )
    
    # Combine all libraries
    set(GSTREAMER_LIBRARIES
        ${GSTREAMER_LIBRARIES}
        ${GSTREAMER_RTSP_SERVER_LIBRARIES}
        ${GSTREAMER_RTSP_LIBRARIES}
        ${GSTREAMER_SDP_LIBRARIES}
        ${GSTREAMER_APP_LIBRARIES}
    )
    
    # Combine all library directories
    set(GSTREAMER_LIBRARY_DIRS
        ${GSTREAMER_LIBRARY_DIRS}
        ${GSTREAMER_RTSP_SERVER_LIBRARY_DIRS}
        ${GSTREAMER_RTSP_LIBRARY_DIRS}
        ${GSTREAMER_SDP_LIBRARY_DIRS}
        ${GSTREAMER_APP_LIBRARY_DIRS}
    )
    
endif()

# Print found information
message(STATUS "GStreamer include dirs: ${GSTREAMER_INCLUDE_DIRS}")
message(STATUS "GStreamer library dirs: ${GSTREAMER_LIBRARY_DIRS}")
message(STATUS "GStreamer libraries: ${GSTREAMER_LIBRARIES}")

# Add executable
add_executable(instant-replay
    main.cpp
)

# Include directories
target_include_directories(instant-replay PRIVATE
    ${GSTREAMER_INCLUDE_DIRS}
)

# Link directories
target_link_directories(instant-replay PRIVATE
    ${GSTREAMER_LIBRARY_DIRS}
)

# Link libraries
target_link_libraries(instant-replay PRIVATE
    ${GSTREAMER_LIBRARIES}
)

# Compiler flags
if(PLATFORM_LINUX OR PLATFORM_MACOS)
    target_compile_options(instant-replay PRIVATE
        -Wall -Wextra -Wpedantic
    )
elseif(PLATFORM_WINDOWS)
    target_compile_options(instant-replay PRIVATE
        /W4
    )
    # Windows-specific: Copy DLLs to output directory (optional)
    # This ensures GStreamer DLLs are available at runtime
    add_custom_command(TARGET instant-replay POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "Note: Ensure GStreamer bin directory is in PATH"
    )
endif()

# Installation
install(TARGETS instant-replay
    RUNTIME DESTINATION bin
)

# Print build configuration
message(STATUS "")
message(STATUS "=== Build Configuration ===")
message(STATUS "Project: ${PROJECT_NAME} ${PROJECT_VERSION}")
message(STATUS "C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "Install Prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "===========================")
message(STATUS "")
