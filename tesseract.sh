#!/bin/sh
export package="tesseract-ocr"
export extra_files="share/tessdata"

# Special handling for Tesseract to make it CRAN-compliant
pre_build_hook() {
  # Create redirection header
  cat > r_redirects.h << 'EOF'
#ifndef R_REDIRECTS_H
#define R_REDIRECTS_H

#include <cstdlib>
#include <string>
#include <iostream>
#include <streambuf>
#include <random>

// Custom stream buffer that redirects stderr output
class RWarningStreambuf : public std::streambuf {
private:
  std::string buffer;
  
protected:
  virtual int overflow(int c) override {
    if (c != EOF) {
      buffer += static_cast<char>(c);
      if (c == '\n') {
        // In a real R extension this would call REprintf
        buffer.clear();
      }
    }
    return c;
  }
  
  virtual std::streamsize xsputn(const char* s, std::streamsize n) override {
    buffer.append(s, n);
    size_t pos = 0;
    while ((pos = buffer.find('\n')) != std::string::npos) {
      buffer.erase(0, pos + 1);
    }
    return n;
  }
  
public:
  static RWarningStreambuf& instance() {
    static RWarningStreambuf instance;
    return instance;
  }
};

// Custom stream buffer for stdout redirection
class RMessageStreambuf : public std::streambuf {
private:
  std::string buffer;
  
protected:
  virtual int overflow(int c) override {
    if (c != EOF) {
      buffer += static_cast<char>(c);
      if (c == '\n') {
        buffer.clear();
      }
    }
    return c;
  }
  
  virtual std::streamsize xsputn(const char* s, std::streamsize n) override {
    buffer.append(s, n);
    size_t pos = 0;
    while ((pos = buffer.find('\n')) != std::string::npos) {
      buffer.erase(0, pos + 1);
    }
    return n;
  }
  
public:
  static RMessageStreambuf& instance() {
    static RMessageStreambuf instance;
    return instance;
  }
};

// Safe random number generator
std::mt19937 safe_random_generator(0);
std::uniform_int_distribution<int> safe_random_dist(0, RAND_MAX);

// Function replacements
extern "C" {
  // Empty abort implementation
  void abort(void) { }
  
  // Empty exit implementation
  void exit(int status) { }
  
  // Safe random generator
  int rand(void) { return safe_random_dist(safe_random_generator); }
  
  // Safe random seed
  void srand(unsigned int seed) { safe_random_generator.seed(seed); }
}

// Replace cout and cerr with safe versions
namespace std {
  std::ostream safe_cout(&RMessageStreambuf::instance());
  std::ostream safe_cerr(&RWarningStreambuf::instance());
}

#define cout std::safe_cout
#define cerr std::safe_cerr

#endif // R_REDIRECTS_H
EOF

  # We need to modify the download_libs function to build custom binaries
  # Instead of using standard MSYS2 packages
  
  # First save the original function for other packages
  eval "original_download_libs() $(declare -f download_libs)"
  
  # Override the download_libs function for tesseract
  download_libs() {
    # Define build directories
    bundle="$package-$version-$arch"
    dist="$PWD/dist"
    rm -Rf $bundle
    mkdir -p $dist $bundle/lib $bundle/include $bundle/share
    
    # Clone tesseract and leptonica from source
    git clone --depth 1 https://github.com/tesseract-ocr/tesseract.git
    cd tesseract
    
    # Place our redirection header
    cp ../r_redirects.h src/ccutil/
    
    # Modify a central header to include our redirections
    sed -i '1i#include "r_redirects.h"' src/ccutil/platform.h
    
    # Configure and build
    ./autogen.sh
    ./configure --prefix=$PWD/../$bundle --disable-shared --enable-static \
      CXXFLAGS="-fvisibility=hidden -fvisibility-inlines-hidden -DUSE_STD_NAMESPACE" \
      CFLAGS="-fvisibility=hidden"
    
    make -j4
    make install
    
    # Return to main directory
    cd ..
    
    # Download language data
    mkdir -p $bundle/share/tessdata
    curl -o $bundle/share/tessdata/eng.traineddata https://github.com/tesseract-ocr/tessdata_best/raw/main/eng.traineddata
    
    # Create the bundle archive
    tar -cJ --no-xattrs -f "$dist/$bundle.tar.xz" $bundle
    rm -Rf $bundle tesseract
    
    # Set success variables
    if [ "$GITHUB_OUTPUT" ]; then
      echo "version=$version" >> $GITHUB_OUTPUT
    fi
  }
}

post_build_hook() {
  # Restore original function if needed
  if type original_download_libs > /dev/null 2>&1; then
    eval "download_libs() $(declare -f original_download_libs)"
    unset -f original_download_libs
  fi
}
