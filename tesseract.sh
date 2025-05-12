#!/bin/sh
export package="tesseract-ocr"
export extra_files="share/tessdata"

# 1) save the original implementation ----------------------------------------
eval "$(declare -f download_libs | \
       sed 's/^download_libs/_download_libs_orig/')"

# 2) new wrapper -------------------------------------------------------------
download_libs() {
  _download_libs_orig "$@" # do the usual MSYS2 download/copy work

  echo "--> rewriting symbols inside $bundle/lib"
  echo "  → listing files in $bundle/lib:"
  ls -1 "$bundle"/lib || true
  OBJCOPY="$(${CC:-gcc} -print-prog-name=objcopy)"
  SYMS="abort exit rand srand _ZSt4cout _ZSt4cerr"
  for lib in "$bundle"/lib/*.a ; do
    for s in $SYMS ; do
      "$OBJCOPY" --redefine-sym "${s}=r_${s}" "$lib"
    done
  done

  # stub that satisfies the renamed symbols
  cat > "$bundle/lib/override.c" <<'EOF'
__attribute__((noreturn)) void r_abort(void){for(;;){}}
__attribute__((noreturn)) void r_exit(int s){for(;;){}}
int  r_rand(void){return 123;}
void r_srand(unsigned x){(void)x;}
void *_r_cout,*_r_cerr;
EOF
  ${CC:-gcc} -c -o "$bundle/lib/override.o" "$bundle/lib/override.c"
  ${AR:-ar}  rcs "$bundle/lib/liboverride.a" "$bundle/lib/override.o"
}
