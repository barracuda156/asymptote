set(GENERATED_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated/include")
file(MAKE_DIRECTORY ${GENERATED_INCLUDE_DIR})

# opsymbols.h
add_custom_command(
        OUTPUT ${GENERATED_INCLUDE_DIR}/opsymbols.h
        COMMAND ${PERL_INTERPRETER}
            ${ASY_SCRIPTS_DIR}/opsymbols.pl
            --campfile ${ASY_RESOURCE_DIR}/camp.l
            --output ${GENERATED_INCLUDE_DIR}/opsymbols.h
        MAIN_DEPENDENCY ${ASY_RESOURCE_DIR}/camp.l
        DEPENDS ${ASY_SCRIPTS_DIR}/opsymbols.pl
)

list(APPEND ASYMPTOTE_INCLUDES ${GENERATED_INCLUDE_DIR})
list(APPEND ASYMPTOTE_GENERATED_HEADERS ${GENERATED_INCLUDE_DIR}/opsymbols.h)

# generated sources
set(GENERATED_SRC_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated/src")
file(MAKE_DIRECTORY ${GENERATED_SRC_DIR})


# run-* files

function(_int_add_runtime_file runtime_file)
    set(RUNTIME_FILE_IN_BASE ${ASY_SRC_TEMPLATES_DIR}/${runtime_file})
    set(RUNTIME_FILES_OUT ${GENERATED_SRC_DIR}/${runtime_file}.cc ${GENERATED_INCLUDE_DIR}/${runtime_file}.h)
    set(RUNTIME_SCRIPT ${ASY_SCRIPTS_DIR}/runtime.pl)
    set(OPSYM_FILE ${GENERATED_INCLUDE_DIR}/opsymbols.h)
    set(RUNTIME_BASE_FILE ${ASY_SRC_TEMPLATES_DIR}/runtimebase.in)

    if (MSVC)
    # hack since msvc does not support "-MG" option to treat missing headers as 
    # generated files
        if (NOT (runtime_file STREQUAL "runtime"))
            set(RUNTIME_FILE_DEP ${GENERATED_INCLUDE_DIR}/runtime.h)
        endif()
    endif()

    add_custom_command(
            OUTPUT ${RUNTIME_FILES_OUT}
            COMMAND ${PERL_INTERPRETER} ${RUNTIME_SCRIPT}
            --opsym-file ${OPSYM_FILE}
            --runtime-base-file ${RUNTIME_BASE_FILE}
            --src-template-dir ${ASY_SRC_TEMPLATES_DIR}
            --prefix ${runtime_file}
            --header-out-dir ${GENERATED_INCLUDE_DIR}
            --src-out-dir ${GENERATED_SRC_DIR}
            MAIN_DEPENDENCY ${RUNTIME_FILE_IN_BASE}.in
            DEPENDS ${RUNTIME_SCRIPT} ${OPSYM_FILE} ${RUNTIME_BASE_FILE} ${RUNTIME_FILE_DEP}
    )
endfunction()

macro(add_runtime_file runtime_file)
    _int_add_runtime_file(${runtime_file})
    list(APPEND ASY_GENERATED_BUILD_SOURCES
            ${GENERATED_SRC_DIR}/${runtime_file}.cc
    )
    list(APPEND ASYMPTOTE_GENERATED_HEADERS
            ${GENERATED_INCLUDE_DIR}/${runtime_file}.h)
endmacro()

foreach(RUNTIME_FILE ${RUNTIME_BUILD_FILES})
    add_runtime_file(${RUNTIME_FILE})
endforeach()


# allsymbols.h
# directory for auxilliary files
set(GENERATED_AUX_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated/aux")
file(MAKE_DIRECTORY ${GENERATED_AUX_DIR})

# generating preprocessed files

set(FINDSYM_FILE ${ASY_SCRIPTS_DIR}/findsym.pl)

# combine all files into allsymbols.h
function(symfile_preprocess src_dir symfile symfile_raw_output_varname header_output_varname)
    set(symfile_raw_output_var ${symfile_raw_output_varname})
    set(processed_output_file ${GENERATED_AUX_DIR}/${symfile}.raw.i)
    set(${symfile_raw_output_var} ${processed_output_file} PARENT_SCOPE)

    if (MSVC)
        set(msvc_flag --msvc)
    endif()

    set(asy_includes_list "$<TARGET_PROPERTY:asy,INCLUDE_DIRECTORIES>")
    set(asy_macros_list "$<TARGET_PROPERTY:asy,COMPILE_DEFINITIONS>")
    set(asy_cxx_std "$<TARGET_PROPERTY:asy,CXX_STANDARD>")

    add_custom_command(
            OUTPUT ${processed_output_file}
            COMMAND ${PY3_INTERPRETER} ${ASY_SCRIPTS_DIR}/gen_preprocessed_depfile.py
            --cxx-compiler=${CMAKE_CXX_COMPILER}
            "$<$<BOOL:${asy_includes_list}>:--include-dirs=${asy_includes_list}>"
            "$<$<BOOL:${asy_cxx_std}>:--cxx-standard=${asy_cxx_std}>"
            "$<$<BOOL:${asy_macros_list}>:--macro-defs=${asy_macros_list}>"
            --out-dep-file=${GENERATED_AUX_DIR}/${symfile}.d
            --out-i-file=${processed_output_file}
            --in-src-file=${src_dir}/${symfile}.cc
            ${msvc_flag}
            DEPFILE ${GENERATED_AUX_DIR}/${symfile}.d
            BYPRODUCTS ${GENERATED_AUX_DIR}/${symfile}.d
            DEPENDS ${src_dir}/${symfile}.cc ${ASY_SCRIPTS_DIR}/gen_preprocessed_depfile.py
            VERBATIM
    )
    # *.symbols.h file
    set(symfile_raw_output_var ${header_output_varname})
    set(sym_header_file ${GENERATED_INCLUDE_DIR}/${symfile}.symbols.h)
    set(${symfile_raw_output_var} ${sym_header_file} PARENT_SCOPE)
    add_custom_command(
            OUTPUT ${sym_header_file}
            COMMAND ${PERL_INTERPRETER} ${FINDSYM_FILE}
                ${sym_header_file}
                ${processed_output_file}
            MAIN_DEPENDENCY ${processed_output_file}
    )


endfunction()

# preprocess each individual symbol files

foreach(SYM_FILE ${SYMBOL_STATIC_BUILD_FILES})
    symfile_preprocess(${ASY_SRC_DIR} ${SYM_FILE} SYMFILE_OUT HEADER_OUT)
    list(APPEND SYMFILE_OUT_LIST ${SYMFILE_OUT})
    list(APPEND ASYMPTOTE_GENERATED_HEADERS ${HEADER_OUT})
endforeach()

foreach(SYM_FILE ${RUNTIME_BUILD_FILES})
    symfile_preprocess(${GENERATED_SRC_DIR} ${SYM_FILE} SYMFILE_OUT HEADER_OUT)
    list(APPEND SYMFILE_OUT_LIST ${SYMFILE_OUT})
    list(APPEND ASYMPTOTE_GENERATED_HEADERS ${HEADER_OUT})
endforeach ()

add_custom_command(
        OUTPUT ${GENERATED_INCLUDE_DIR}/allsymbols.h
        COMMAND ${PERL_INTERPRETER} ${FINDSYM_FILE}
            ${GENERATED_INCLUDE_DIR}/allsymbols.h
            ${SYMFILE_OUT_LIST}
        DEPENDS ${FINDSYM_FILE} ${SYMFILE_OUT_LIST}
)

list(APPEND ASYMPTOTE_GENERATED_HEADERS ${GENERATED_INCLUDE_DIR}/allsymbols.h)

# keywords.h

add_custom_command(
        OUTPUT ${GENERATED_INCLUDE_DIR}/keywords.h
        COMMAND ${PERL_INTERPRETER} ${ASY_SCRIPTS_DIR}/keywords.pl
            --camplfile ${ASY_RESOURCE_DIR}/camp.l
            --output ${GENERATED_INCLUDE_DIR}/keywords.h
            --process-file ${ASY_SRC_DIR}/process.cc
        MAIN_DEPENDENCY ${ASY_RESOURCE_DIR}/camp.l
        DEPENDS ${ASY_SCRIPTS_DIR}/keywords.pl ${ASY_SRC_DIR}/process.cc
)

list(APPEND ASYMPTOTE_GENERATED_HEADERS ${GENERATED_INCLUDE_DIR}/keywords.h)

add_custom_target(asy_gen_headers
        DEPENDS ${ASYMPTOTE_GENERATED_HEADERS}
)

set(camp_lex_output ${GENERATED_SRC_DIR}/lex.yy.cc)
set(camp_l_file ${ASY_RESOURCE_DIR}/camp.l)

# flex + bison
add_custom_command(
        OUTPUT ${camp_lex_output}
        COMMAND ${FLEX_EXECUTABLE} -o ${camp_lex_output} ${camp_l_file}
        MAIN_DEPENDENCY ${camp_l_file}
)

list(APPEND ASY_GENERATED_BUILD_SOURCES ${camp_lex_output})

# bison

set(bison_output ${GENERATED_SRC_DIR}/camp.tab.cc)
set(bison_header ${GENERATED_INCLUDE_DIR}/camp.tab.h)
set(bison_input ${ASY_RESOURCE_DIR}/camp.y)
add_custom_command(
        OUTPUT ${bison_output} ${bison_header}
        COMMAND ${BISON_EXECUTABLE} -t --header=${bison_header} -o ${bison_output} ${bison_input}
        MAIN_DEPENDENCY ${bison_input}
)

list(APPEND ASY_GENERATED_BUILD_SOURCES ${bison_output})
list(APPEND ASYMPTOTE_GENERATED_HEADERS ${bison_header})

# macro files
message(STATUS "Generating revision.cc file")
set(revision_cc_file ${GENERATED_SRC_DIR}/revision.cc)
configure_file(${ASY_RESOURCE_DIR}/template_rev.cc.in ${revision_cc_file})
list(APPEND ASY_GENERATED_BUILD_SOURCES ${revision_cc_file})
