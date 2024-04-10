include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(jt_cmake_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(jt_cmake_setup_options)
  option(jt_cmake_ENABLE_HARDENING "Enable hardening" ON)
  option(jt_cmake_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    jt_cmake_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    jt_cmake_ENABLE_HARDENING
    OFF)

  jt_cmake_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR jt_cmake_PACKAGING_MAINTAINER_MODE)
    option(jt_cmake_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(jt_cmake_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(jt_cmake_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(jt_cmake_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(jt_cmake_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(jt_cmake_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(jt_cmake_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(jt_cmake_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(jt_cmake_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(jt_cmake_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(jt_cmake_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(jt_cmake_ENABLE_PCH "Enable precompiled headers" OFF)
    option(jt_cmake_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(jt_cmake_ENABLE_IPO "Enable IPO/LTO" ON)
    option(jt_cmake_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(jt_cmake_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(jt_cmake_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(jt_cmake_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(jt_cmake_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(jt_cmake_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(jt_cmake_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(jt_cmake_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(jt_cmake_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(jt_cmake_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(jt_cmake_ENABLE_PCH "Enable precompiled headers" OFF)
    option(jt_cmake_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      jt_cmake_ENABLE_IPO
      jt_cmake_WARNINGS_AS_ERRORS
      jt_cmake_ENABLE_USER_LINKER
      jt_cmake_ENABLE_SANITIZER_ADDRESS
      jt_cmake_ENABLE_SANITIZER_LEAK
      jt_cmake_ENABLE_SANITIZER_UNDEFINED
      jt_cmake_ENABLE_SANITIZER_THREAD
      jt_cmake_ENABLE_SANITIZER_MEMORY
      jt_cmake_ENABLE_UNITY_BUILD
      jt_cmake_ENABLE_CLANG_TIDY
      jt_cmake_ENABLE_CPPCHECK
      jt_cmake_ENABLE_COVERAGE
      jt_cmake_ENABLE_PCH
      jt_cmake_ENABLE_CACHE)
  endif()

  jt_cmake_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (jt_cmake_ENABLE_SANITIZER_ADDRESS OR jt_cmake_ENABLE_SANITIZER_THREAD OR jt_cmake_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(jt_cmake_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(jt_cmake_global_options)
  if(jt_cmake_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    jt_cmake_enable_ipo()
  endif()

  jt_cmake_supports_sanitizers()

  if(jt_cmake_ENABLE_HARDENING AND jt_cmake_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR jt_cmake_ENABLE_SANITIZER_UNDEFINED
       OR jt_cmake_ENABLE_SANITIZER_ADDRESS
       OR jt_cmake_ENABLE_SANITIZER_THREAD
       OR jt_cmake_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${jt_cmake_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${jt_cmake_ENABLE_SANITIZER_UNDEFINED}")
    jt_cmake_enable_hardening(jt_cmake_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(jt_cmake_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(jt_cmake_warnings INTERFACE)
  add_library(jt_cmake_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  jt_cmake_set_project_warnings(
    jt_cmake_warnings
    ${jt_cmake_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(jt_cmake_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    jt_cmake_configure_linker(jt_cmake_options)
  endif()

  include(cmake/Sanitizers.cmake)
  jt_cmake_enable_sanitizers(
    jt_cmake_options
    ${jt_cmake_ENABLE_SANITIZER_ADDRESS}
    ${jt_cmake_ENABLE_SANITIZER_LEAK}
    ${jt_cmake_ENABLE_SANITIZER_UNDEFINED}
    ${jt_cmake_ENABLE_SANITIZER_THREAD}
    ${jt_cmake_ENABLE_SANITIZER_MEMORY})

  set_target_properties(jt_cmake_options PROPERTIES UNITY_BUILD ${jt_cmake_ENABLE_UNITY_BUILD})

  if(jt_cmake_ENABLE_PCH)
    target_precompile_headers(
      jt_cmake_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(jt_cmake_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    jt_cmake_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(jt_cmake_ENABLE_CLANG_TIDY)
    jt_cmake_enable_clang_tidy(jt_cmake_options ${jt_cmake_WARNINGS_AS_ERRORS})
  endif()

  if(jt_cmake_ENABLE_CPPCHECK)
    jt_cmake_enable_cppcheck(${jt_cmake_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(jt_cmake_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    jt_cmake_enable_coverage(jt_cmake_options)
  endif()

  if(jt_cmake_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(jt_cmake_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(jt_cmake_ENABLE_HARDENING AND NOT jt_cmake_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR jt_cmake_ENABLE_SANITIZER_UNDEFINED
       OR jt_cmake_ENABLE_SANITIZER_ADDRESS
       OR jt_cmake_ENABLE_SANITIZER_THREAD
       OR jt_cmake_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    jt_cmake_enable_hardening(jt_cmake_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
