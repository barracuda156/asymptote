# tinyexr

set(TINYEXR_REPO_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/tinyexr CACHE INTERNAL "tinyexr repo location")
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/thirdparty_impl/tinyexr_impl/)

list(APPEND ASY_STATIC_LIBARIES tinyexr-impl)
list(APPEND ASYMPTOTE_INCLUDES $<TARGET_PROPERTY:tinyexr-impl,INCLUDE_DIRECTORIES>)
