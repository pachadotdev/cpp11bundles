#!/bin/sh
export package="tesseract-ocr"
export extra_files="share/tessdata"
export extra_includes="leptonica tesseract"

# Define a post-build hook to verify and fix includes
post_build_hook() {
  echo "Running post-build verification..."
  
  # Check if leptonica headers were included
  if [ ! -d "$RWINLIB/include/leptonica" ]; then
    echo "ERROR: Leptonica headers were not included automatically"
    echo "Current includes directory content:"
    find "$RWINLIB/include" -type d | sort
    
    # Check if leptonica headers exist in the MSYS2 environment
    LEPTONICA_PATH="/${MSYSTEM,,}/include/leptonica"
    if [ -d "$LEPTONICA_PATH" ]; then
      echo "Found Leptonica headers at $LEPTONICA_PATH - copying manually"
      mkdir -p "$RWINLIB/include/leptonica"
      cp -r "$LEPTONICA_PATH"/* "$RWINLIB/include/leptonica/"
      
      echo "After manual copy:"
      find "$RWINLIB/include" -type d | sort
    else
      echo "CRITICAL ERROR: Could not find Leptonica headers in MSYS2 environment"
      find "/${MSYSTEM,,}/include" -type d | grep -i lept || echo "No Leptonica directory found!"
    fi
  else
    echo "Leptonica headers were correctly included at $RWINLIB/include/leptonica"
    ls -la "$RWINLIB/include/leptonica"
  fi
  
  # Download tessdata files
  mkdir -p "$RWINLIB/share/tessdata"
  if [ ! -f "$RWINLIB/share/tessdata/eng.traineddata" ]; then
    curl -L -o "$RWINLIB/share/tessdata/eng.traineddata" \
      https://github.com/tesseract-ocr/tessdata_best/raw/main/eng.traineddata
    curl -L -o "$RWINLIB/share/tessdata/osd.traineddata" \
      https://github.com/tesseract-ocr/tessdata_best/raw/main/osd.traineddata
  fi
}
