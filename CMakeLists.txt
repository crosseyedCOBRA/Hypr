cmake_minimum_required(VERSION 3.5)

set(CMAKE_CXX_COMPILER "/bin/g++")

project(zaris
    VERSION 0.1
    DESCRIPTION "A Modern OOP C++ Window Manager"
)

set(CMAKE_MESSAGE_LOG_LEVEL "STATUS")

message(STATUS "Configuring zaris!")

add_compile_options(-std=c++17)
add_compile_options(-Wall -Wextra)
find_package(Threads REQUIRED)

find_package(PkgConfig REQUIRED)
pkg_check_modules(deps REQUIRED IMPORTED_TARGET glib-2.0 xcb-randr xcb-ewmh xcb-xinerama xcb-cursor xcb-keysyms xcb-icccm xcb-util xcb-composite xcb-damage xcb-render xcb-renderutil gl x11)

file(GLOB_RECURSE SRCFILES "src/*.cpp")

add_executable(zaris ${SRCFILES})

IF(CMAKE_BUILD_TYPE MATCHES Debug OR CMAKE_BUILD_TYPE MATCHES DEBUG)
    message(STATUS "Configuring zaris in Debug with CMake!")
ELSE()
    add_compile_options(-Ofast)
    message(STATUS "Configuring zaris in Release with CMake!")
ENDIF(CMAKE_BUILD_TYPE MATCHES Debug OR CMAKE_BUILD_TYPE MATCHES DEBUG)

IF(UNIX AND NOT APPLE)
    target_link_libraries(zaris rt)
ENDIF()

set(CPACK_PROJECT_NAME ${PROJECT_NAME})
set(CPACK_PROJECT_VERSION ${PROJECT_VERSION})
include(CPack)

target_link_libraries(zaris PkgConfig::deps)

target_link_libraries(zaris
        xcb
        xcb-ewmh
        xcb-icccm
        xcb-keysyms
        xcb-randr
        xcb-xinerama
        xcb-cursor
        xcb-shape
        xcb-util
        xcb-composite
        xcb-damage
        xcb-render
        xcb-render-util
        GL
        X11
        ${CMAKE_THREAD_LIBS_INIT}
)

IF(CMAKE_BUILD_TYPE MATCHES Debug OR CMAKE_BUILD_TYPE MATCHES DEBUG)
    SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pg -no-pie -fno-builtin")
    SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -pg -no-pie -fno-builtin")
    SET(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -pg -no-pie -fno-builtin")
ENDIF(CMAKE_BUILD_TYPE MATCHES Debug OR CMAKE_BUILD_TYPE MATCHES DEBUG)
