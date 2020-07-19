# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "LibArchive"
version = v"3.4.3"

# Collection of sources required to complete build
sources = [
    GitSource("https://github.com/libarchive/libarchive.git",
              "fc6563f5130d8a7ee1fc27c0e55baef35119f26c")
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir/libarchive*/
export CPPFLAGS="-I${includedir} -fPIC -DPIC"
autoreconf -fi
./configure --prefix=${prefix} \
    --build=${MACHTYPE} \
    --host=${target} \
    --with-expat \
    --without-openssl \
    --without-xml2 \
    --without-nettle \
    --without-zstd \
    --disable-bsdtar \
    --disable-bsdcat \
    --disable-bsdcpio
make -j${nproc}
make install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = supported_platforms()

# The products that we will ensure are always built
products = [
    LibraryProduct("libarchive", :libarchive)
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency("acl_jll"),
    Dependency("Attr_jll"),
    Dependency("Bzip2_jll"),
    Dependency("Expat_jll"),
    Dependency("Libiconv_jll"),
    Dependency("Lz4_jll"),
    Dependency("XZ_jll"),
    Dependency("Zlib_jll"),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies)
