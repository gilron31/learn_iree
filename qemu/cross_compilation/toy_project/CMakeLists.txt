 cmake_minimum_required(VERSION 3.15)

project(toy_project LANGUAGES C CXX)

add_executable(main tools/main.cc)

add_library(func_a STATIC src/func_a.cc src/func_a.h)
target_include_directories(func_a PUBLIC .)


target_link_libraries(main PUBLIC func_a)
target_include_directories(main PUBLIC src)