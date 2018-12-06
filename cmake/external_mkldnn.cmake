# ******************************************************************************
# Copyright 2017-2018 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ******************************************************************************

include(ExternalProject)

#------------------------------------------------------------------------------
# Fetch and install MKL-DNN
#------------------------------------------------------------------------------

set(MKLDNN_LIB libmkldnn${CMAKE_SHARED_LIBRARY_SUFFIX})
if (${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(MKLML_LIB libmklml_intel.so)
    set(OMP_LIB libiomp5.so)
elseif (APPLE)
    set(MKLML_LIB libmklml.dylib)
    set(OMP_LIB libiomp5.dylib)
elseif (WIN32)
    set(MKLML_LIB mklml.dll)
    set(OMP_LIB libiomp5md.dll)
endif()

if(MKLDNN_INCLUDE_DIR AND MKLDNN_LIB_DIR)
    ExternalProject_Add(
        ext_mkldnn
        DOWNLOAD_COMMAND ""
        UPDATE_COMMAND ""
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
        INSTALL_COMMAND ""
        )
    add_library(libmkldnn INTERFACE)
    target_include_directories(libmkldnn SYSTEM INTERFACE ${MKLDNN_INCLUDE_DIR})
    target_link_libraries(libmkldnn INTERFACE
        ${MKLDNN_LIB_DIR}/${MKLDNN_LIB}
        ${MKLDNN_LIB_DIR}/${MKLML_LIB}
        ${MKLDNN_LIB_DIR}/${OMP_LIB}
        )

    install(DIRECTORY ${MKLDNN_LIB_DIR}/ DESTINATION ${NGRAPH_INSTALL_LIB})
    return()
endif()

# This section sets up MKL as an external project to be used later by MKLDNN

set(MKLURLROOT "https://github.com/intel/mkl-dnn/releases/download/v0.17/")
set(MKLVERSION "2019.0.1.20180928")
set(NGRAPH_USE_MKLML FALSE)

if (${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(MKLPACKAGE "mklml_lnx_${MKLVERSION}.tgz")
    set(MKL_SHA1_HASH 0d9cc8bfc2c1a1e3df5e0b07e2f363bbf934a7e9)
elseif (APPLE)
    set(MKLPACKAGE "mklml_mac_${MKLVERSION}.tgz")
    set(MKL_SHA1_HASH 232787f41cb42f53f5b7e278d8240f6727896133)
elseif (WIN32)
    set(MKLPACKAGE "mklml_win_${MKLVERSION}.zip")
    set(MKL_SHA1_HASH 97f01ab854d8ee88cc0429f301df84844d7cce6b)
endif()
set(MKL_LIBS ${MKLML_LIB} ${OMP_LIB})
set(MKLURL ${MKLURLROOT}${MKLPACKAGE})

SET(MKLDNN_FLAG "-Wno-error=strict-overflow -Wno-error=unused-result -Wno-error=array-bounds")
SET(MKLDNN_FLAG "${MKLDNN_FLAG} -Wno-unused-result -Wno-unused-value")
SET(MKLDNN_CFLAG "${CMAKE_C_FLAGS} ${MKLDNN_FLAG}")
SET(MKLDNN_CXXFLAG "${CMAKE_CXX_FLAGS} ${MKLDNN_FLAG}")

ExternalProject_Add(
    ext_mkl
    PREFIX mkl
    URL ${MKLURL}
    URL_HASH SHA1=${MKL_SHA1_HASH}
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ""
    UPDATE_COMMAND ""
    DOWNLOAD_NO_PROGRESS TRUE
    EXCLUDE_FROM_ALL TRUE
)
ExternalProject_Get_Property(ext_mkl source_dir)
set(MKL_ROOT ${EXTERNAL_PROJECTS_ROOT}/mkldnn/src/external/mkl)
set(MKL_SOURCE_DIR ${source_dir})
add_library(libmkl INTERFACE)
add_dependencies(libmkl ext_mkl)
foreach(LIB ${MKL_LIBS})
    target_link_libraries(libmkl INTERFACE ${MKL_SOURCE_DIR}/src/ext_mkl/lib/${LIB})
endforeach()
set_target_properties(libmkl PROPERTIES INSTALL_RPATH "$ORIGIN")

if(NGRAPH_USE_MKLML)
    set(MKLDNN_USE_MKL DEF)
    set(MKLDNN_DEPENDS ext_mkl)
    set(MKLML_LIB libmkl)
else()
    set(MKLDNN_USE_MKL NONE)
    set(MKLDNN_DEPENDS "")
    set(MKLML_LIB "")
endif()

set(MKLDNN_GIT_REPO_URL https://github.com/intel/mkl-dnn)
set(MKLDNN_GIT_TAG "830a100")
if(NGRAPH_LIB_VERSIONING_ENABLE)
    set(MKLDNN_PATCH_FILE mkldnn.patch)
else()
    set(MKLDNN_PATCH_FILE mkldnn_no_so_link.patch)
endif()

# The 'BUILD_BYPRODUCTS' argument was introduced in CMake 3.2.
if(${CMAKE_VERSION} VERSION_LESS 3.2)
    ExternalProject_Add(
        ext_mkldnn
        DEPENDS ${MKLDNN_DEPENDS}
        GIT_REPOSITORY ${MKLDNN_GIT_REPO_URL}
        GIT_TAG ${MKLDNN_GIT_TAG}
        UPDATE_COMMAND ""
        CONFIGURE_COMMAND
        # Patch gets mad if it applied for a second time so:
        #    --forward tells patch to ignore if it has already been applied
        #    --reject-file tells patch to not right a reject file
        #    || exit 0 changes the exit code for the PATCH_COMMAND to zero so it is not an error
        # I don't like it, but it works
        PATCH_COMMAND patch -p1 --forward --reject-file=- -i ${CMAKE_SOURCE_DIR}/cmake/${MKLDNN_PATCH_FILE} || exit 0
        # Uncomment below with any in-flight MKL-DNN patches
        # PATCH_COMMAND patch -p1 < ${CMAKE_SOURCE_DIR}/third-party/patches/mkldnn-cmake-openmp.patch
        CMAKE_ARGS
            -DWITH_TEST=OFF
            -DWITH_EXAMPLE=OFF
            -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
            -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
            -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
            -DCMAKE_INSTALL_PREFIX=${EXTERNAL_PROJECTS_ROOT}/mkldnn
            -DMKLDNN_ENABLE_CONCURRENT_EXEC=ON
            -DMKLROOT=${MKL_ROOT}
            "-DARCH_OPT_FLAGS=-march=${NGRAPH_TARGET_ARCH} -mtune=${NGRAPH_TARGET_ARCH}"
            -DMKLDNN_USE_MKL=${MKLDNN_USE_MKL}
            -DCMAKE_C_FLAGS=${MKLDNN_CFLAG}
            -DCMAKE_CXX_FLAGS=${MKLDNN_CXXFLAG}
            -DMKLDNN_USE_MKL=NONE
            -DMKLDNN_THREADING=TBB
        TMP_DIR "${EXTERNAL_PROJECTS_ROOT}/mkldnn/tmp"
        STAMP_DIR "${EXTERNAL_PROJECTS_ROOT}/mkldnn/stamp"
        DOWNLOAD_DIR "${EXTERNAL_PROJECTS_ROOT}/mkldnn/download"
        SOURCE_DIR "${EXTERNAL_PROJECTS_ROOT}/mkldnn/src"
        BINARY_DIR "${EXTERNAL_PROJECTS_ROOT}/mkldnn/build"
        INSTALL_DIR "${EXTERNAL_PROJECTS_ROOT}/mkldnn"
        EXCLUDE_FROM_ALL TRUE
        )
else()
    ExternalProject_Add(
        ext_mkldnn
        DEPENDS ${MKLDNN_DEPENDS}
        GIT_REPOSITORY ${MKLDNN_GIT_REPO_URL}
        GIT_TAG ${MKLDNN_GIT_TAG}
        UPDATE_COMMAND ""
        # Patch gets mad if it applied for a second time so:
        #    --forward tells patch to ignore if it has already been applied
        #    --reject-file tells patch to not right a reject file
        #    || exit 0 changes the exit code for the PATCH_COMMAND to zero so it is not an error
        # I don't like it, but it works
        PATCH_COMMAND patch -p1 --forward --reject-file=- -i ${CMAKE_SOURCE_DIR}/cmake/${MKLDNN_PATCH_FILE} || exit 0
        # Uncomment below with any in-flight MKL-DNN patches
        # PATCH_COMMAND patch -p1 < ${CMAKE_SOURCE_DIR}/third-party/patches/mkldnn-cmake-openmp.patch
        CMAKE_ARGS
            -DWITH_TEST=OFF
            -DWITH_EXAMPLE=OFF
            -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
            -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
            -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
            -DCMAKE_INSTALL_PREFIX=${EXTERNAL_PROJECTS_ROOT}/mkldnn
            -DMKLDNN_ENABLE_CONCURRENT_EXEC=ON
            -DMKLROOT=${MKL_ROOT}
            "-DARCH_OPT_FLAGS=-march=${NGRAPH_TARGET_ARCH} -mtune=${NGRAPH_TARGET_ARCH}"
            -DMKLDNN_USE_MKL=${MKLDNN_USE_MKL}
            -DCMAKE_C_FLAGS=${MKLDNN_CFLAG}
            -DCMAKE_CXX_FLAGS=${MKLDNN_CXXFLAG}
            -DMKLDNN_USE_MKL=NONE
            -DMKLDNN_THREADING=TBB
        TMP_DIR "${EXTERNAL_PROJECTS_ROOT}/mkldnn/tmp"
        STAMP_DIR "${EXTERNAL_PROJECTS_ROOT}/mkldnn/stamp"
        DOWNLOAD_DIR "${EXTERNAL_PROJECTS_ROOT}/mkldnn/download"
        SOURCE_DIR "${EXTERNAL_PROJECTS_ROOT}/mkldnn/src"
        BINARY_DIR "${EXTERNAL_PROJECTS_ROOT}/mkldnn/build"
        INSTALL_DIR "${EXTERNAL_PROJECTS_ROOT}/mkldnn"
        BUILD_BYPRODUCTS "${EXTERNAL_PROJECTS_ROOT}/mkldnn/include/mkldnn.hpp"
        EXCLUDE_FROM_ALL TRUE
        )
endif()

# CPU backend has dependency on CBLAS
ExternalProject_Add_Step(
    ext_mkldnn
    PrepareMKL
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${MKL_SOURCE_DIR} ${MKL_ROOT}
    DEPENDEES download
    DEPENDERS configure
    )

add_custom_command(TARGET ext_mkldnn POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${EXTERNAL_PROJECTS_ROOT}/mkldnn/lib ${NGRAPH_BUILD_DIR}
    COMMENT "Move mkldnn libraries to ngraph build directory"
)

add_library(libmkldnn INTERFACE)
add_dependencies(libmkldnn ext_mkldnn)
target_include_directories(libmkldnn SYSTEM INTERFACE ${EXTERNAL_PROJECTS_ROOT}/mkldnn/include)
target_link_libraries(libmkldnn INTERFACE
    ${EXTERNAL_PROJECTS_ROOT}/mkldnn/lib/${MKLDNN_LIB}
    ${MKLML_LIB}
    )

install(DIRECTORY ${EXTERNAL_PROJECTS_ROOT}/mkldnn/lib/ DESTINATION ${NGRAPH_INSTALL_LIB} OPTIONAL)
