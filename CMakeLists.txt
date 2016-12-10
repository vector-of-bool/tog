cmake_minimum_required(VERSION 3.7)
project(Tog VERSION 0.0.0)

include(CMakeToolsHelpers)

set(Boost_USE_STATIC_LIBS TRUE)
find_package(Boost 1.61 REQUIRED system filesystem)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/bin")

find_program(MIX_PROGRAM mix DOC "Mix Elixir build tool")
add_library(nlohmann::json INTERFACE IMPORTED)
set_target_properties(nlohmann::json PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${PROJECT_SOURCE_DIR}/extern/nlohmann-json/src"
    INTERFACE_COMPILE_FEATURES cxx_auto_type
    )

get_filename_component(MIX_DEPS_STAMP "${CMAKE_CURRENT_BINARY_DIR}/mix-deps.stamp" ABSOLUTE)

add_custom_command(OUTPUT "${MIX_DEPS_STAMP}"
    COMMAND "${MIX_PROGRAM}" deps.get
    COMMAND "${MIX_PROGRAM}" deps.compile
    COMMAND "${CMAKE_COMMAND}" -E touch "${MIX_DEPS_STAMP}"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/mix.exs"
    COMMENT "Download and compile Elixir dependencies"
    )

add_custom_target(mix ALL DEPENDS "${MIX_DEPS_STAMP}")

add_subdirectory(togc)
