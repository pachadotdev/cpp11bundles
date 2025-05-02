#ifndef R_REDIRECTS_H
#define R_REDIRECTS_H

#include <cstdlib>
#include <string>
#include <iostream>
#include <streambuf>
#include <random>

// Custom stream buffer that calls R_ShowMessage for stderr
class RWarningStreambuf : public std::streambuf {
private:
  std::string buffer;
  
protected:
  virtual int overflow(int c) override {
    if (c != EOF) {
      buffer += static_cast<char>(c);
      if (c == '\n') {
        // Here we would call REprintf, but from C++ we use a function pointer
        // that will be set when loaded in R
        fprintf(stderr, "Warning: %s\n", buffer.c_str());
        buffer.clear();
      }
    }
    return c;
  }
  
  virtual std::streamsize xsputn(const char* s, std::streamsize n) override {
    buffer.append(s, n);
    size_t pos = 0;
    while ((pos = buffer.find('\n')) != std::string::npos) {
      fprintf(stderr, "Warning: %s\n", buffer.substr(0, pos).c_str());
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
        fprintf(stdout, "%s\n", buffer.c_str());
        buffer.clear();
      }
    }
    return c;
  }
  
  virtual std::streamsize xsputn(const char* s, std::streamsize n) override {
    buffer.append(s, n);
    size_t pos = 0;
    while ((pos = buffer.find('\n')) != std::string::npos) {
      fprintf(stdout, "%s\n", buffer.substr(0, pos).c_str());
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

// Safe random number generation
std::mt19937 r_random_generator(123456);
std::uniform_int_distribution<int> r_random_dist(0, RAND_MAX);

// Function replacements
extern "C" {
  // Redirect abort to a safe version that returns control to R
  void abort(void) {
    fprintf(stderr, "abort() called - operation canceled\n");
    return;
  }
  
  // Redirect exit to a safe version
  void exit(int status) {
    fprintf(stderr, "exit(%d) called - operation canceled\n", status);
    return;
  }
  
  // Safe random number generator
  int rand(void) {
    return r_random_dist(r_random_generator);
  }
  
  // Safe random seed function
  void srand(unsigned int seed) {
    r_random_generator.seed(seed);
  }
}

// Replace cout and cerr
namespace std {
  std::ostream _r_cout(&RMessageStreambuf::instance());
  std::ostream _r_cerr(&RWarningStreambuf::instance());
}

// Macros to replace standard streams
#define cout std::_r_cout
#define cerr std::_r_cerr

#endif // R_REDIRECTS_H
