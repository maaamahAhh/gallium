# This is free and unencumbered software released into the public domain.
# For more information, please refer to <https://unlicense.org>.

cmake_minimum_required(VERSION 3.14)
project(GalliumInstaller LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(GalliumInstaller WIN32
    main.cc
    miniz.c
    resource.rc
)

target_include_directories(GalliumInstaller PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

target_link_libraries(GalliumInstaller PRIVATE
    gdiplus
    shell32
    ole32
    advapi32
    shlwapi
    user32
    kernel32
    dwmapi
)

# Embed gallium_release.zip as a resource if it exists
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/data/gallium_release.zip")
    target_compile_definitions(GalliumInstaller PRIVATE HAS_EMBEDDED_ZIP)
endif()
