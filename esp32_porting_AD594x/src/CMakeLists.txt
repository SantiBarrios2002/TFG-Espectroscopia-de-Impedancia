# This file was automatically generated for projects
# without default 'CMakeLists.txt' file.

FILE(GLOB_RECURSE app_sources ${CMAKE_SOURCE_DIR}/src/*.*)
FILE(GLOB_RECURSE lib_sources ${CMAKE_SOURCE_DIR}/lib/*.*)

idf_component_register(SRCS ${app_sources} ${lib_sources}
                      INCLUDE_DIRS ${CMAKE_SOURCE_DIR}/include
                                   ${CMAKE_SOURCE_DIR}/lib)
