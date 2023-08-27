#!/usr/bin/env bash

# FIXME the output pdf has an offset of 5x5 pixels at 1200dpi
# via "pdftocairo -png -f 1 -singlefile -r 1200 output.pdf output.pdf.page1.1200dpi"

# test-page-a4-100pt.svg.600dpi.pdf
# error: 3x3 pixels too much for the bbox l/t offsets
#   input : 1667 x 1667
#   output: 1664 x 1664
# bbox x/y is okay = width/height of object

# TODO calibrate the image positions?
# this feels like a workaround for some issue with latex
# but until i find that issues, its better than nothing



# TODO use PNG images instead of JP2 images to get better quality. JP2 is blurry

# remove frame of image:
# convert -trim +repage input.png output.png

# FIXME page 61: image is darker than in chrome PDF viewer. blame pdftoppm?
# https://github.com/milahu/pdf-rendering-chromium-versus-pdftoppm
# https://gitlab.freedesktop.org/poppler/poppler/-/issues/1423
# https://stackoverflow.com/questions/6605006/convert-pdf-to-image-with-high-resolution

# chrome PDF viewer is based on pdfium
# https://pdfium.googlesource.com/pdfium/
# https://github.com/chromium/pdfium
# https://github.com/NixOS/nixpkgs/issues/107451 # Package request: PDFium
# https://docs.rs/pdfium-render/latest/pdfium_render/
#   https://github.com/ajrcarey/pdfium-render/issues/90 # Rendering PDFs into a PNG with transparent background
# https://stackoverflow.com/questions/518878/how-to-render-pdfs-using-c-sharp
# https://stackoverflow.com/questions/29527123/how-does-chrome-render-pdfs-from-html-so-well

# https://stackoverflow.com/questions/54258482/how-to-convert-a-pdf-to-a-bitmap-image-using-pdfiumviewer

# FIXME page 61: image position is wrong. blame scale_x versus scale_y detection?

# FIXME q39 looks bad on some pages! pages 46 47 of "Stephen R. Covey - Die 7 Wege zu glücklichen Beziehungen. 2021.pdf" (70MB)
# TODO find a way to compare images
# to quantify the distance
# to quantify the similarity
# when reducing the quality, the distance grows
# when the distance is too much, we increase the quality
# https://stackoverflow.com/questions/1927660/compare-two-images-the-python-linux-way
# https://stackoverflow.com/questions/189943/how-can-i-quantify-difference-between-two-images

jp2_quality_min=48
jp2_quality_inc=1
jp2_quality_max=65

# TODO share this with
# https://graphicdesign.stackexchange.com/questions/19295/reduce-file-size-of-pdf-eps-from-adobe-illustrator
# https://graphicdesign.stackexchange.com/questions/138684/why-is-pdf-much-larger-than-png-for-a-vector-design
# https://graphicdesign.stackexchange.com/questions/45491/how-do-i-reduce-pdf-file-sizes
# https://tex.stackexchange.com/questions/47076/replacing-vector-images-in-a-pdf-with-raster-images
# https://support.neuxpower.com/hc/en-us/articles/360022343714-What-are-Content-Streams-in-PDF-files-and-how-to-compress-them-
# https://www.wecompress.com/en/analyze
# https://www.gogoprint.co.th/en/blog/tips-tricks-compress-file/
# https://www.verypdf.com/wordpress/201308/compressingoptimizing-vectors-in-pdf-38070.html
# https://cloudconvert.com/compress-pdf
# https://stackoverflow.com/questions/8755366/compressing-optimizing-vectors-in-pdf

# compress large vector graphics in the "content stream" of a PDF file
# https://community.adobe.com/t5/acrobat-discussions/pdf-size-is-content-stream-the-problem/m-p/2286382
# https://support.neuxpower.com/hc/en-us/articles/360022343714-What-are-Content-Streams-in-PDF-files-and-how-to-compress-them-
#   currently it is not possible for NXPowerLite Desktop or WeCompress to manipulate or compress Content Streams data.
# https://neuxpower.com/blog/why-is-pdf-file-so-big-and-how-to-reduce-pdf-file-size
#   Unlike images which can be resized or recompressed with a more optimal quality to reduce them in size, content streams tend to be large and cannot be directly compressed.
#   However, there are workarounds to compress the size of PDF files made from content streams.
#   The main one is to try and reprint the PDF using a browser PDF printer and then use a PDF compressor to reduce the size of the resulting file.
#   - no, the "print to PDF" quickfix did not help in my case, the printed PDF was still 70 MB large, same as the original PDF.
# https://www.wecompress.com/en/analyze



set -e
set -u
set -x

input_pdf_path="$1"
output_pdf_path="$2"

first_page="$3"
last_page="$4"

# get absolute paths
input_pdf_path="$(readlink -f "$input_pdf_path")"
output_pdf_path="$(readlink -f "$output_pdf_path")"

combined_output_pdf_path="$output_pdf_path"

# 600dpi is the typical resolution for printing
# 720dpi is the resolution of chrome PDF reader at full zoom (500%)
#images_resolution=600
images_resolution=720

#pages=all
keep_temp_files=false
keep_temp_files=true # debug

# float math precision in digits after "."
float_precision_digits=20

tempdir=$(mktemp -d --suffix=-pdf-compress-vector-graphics)
echo "using tempdir $tempdir"

ln -s "$input_pdf_path" $tempdir/input.pdf
ln -s "$output_pdf_path" $tempdir/output.pdf

#workdir=$PWD

read _ num_pages < <(pdfinfo "$input_pdf_path" | grep "^Pages:")

if ! ((1 <= num_pages && num_pages <= 999999)); then
  echo "error: invalid number of pages from pdfinfo: $pages"
  exit 1
fi

# no. this uses too much disk space.
# one page's ppm file has about 50MB
#exec pdftoppm -progress -png -r $resolution "$input_pdf_path" "$output_pdf_path"
#exit

# TODO?
#potrace_args=()
# no. tracing bitmaps produces either large files or ugly images
# so its much easier to replace the PDF vector graphics with JP2 raster graphics

# TODO generate the "onlyvectors" pdf file
# https://stackoverflow.com/questions/29657335/how-can-i-remove-all-images-from-a-pdf
# gs -o onlyvectors.pdf -sDEVICE=pdfwrite -dFILTERIMAGE -dFILTERTEXT input.pdf

page_number_pad_len=${#num_pages}
page_number_pad_fmt="%0${page_number_pad_len}i"

# observed white 600dpi png sizes: 66888
# png file size at 600dpi:
# 1165486 page-038-0600dpi.png
# 66888   page-039-0600dpi.png # empty. 66888 == 72 * 929
# 66888   page-040-0600dpi.png # empty
# 66888   page-041-0600dpi.png # empty
page_png_size_min=71000

#page_vectors_pdf_size_min=200000 # 200KB. large pages have about 1MB vectors
page_vectors_pdf_size_min=0 # debug: compress all pages

jp2_pdf_path_list=()
jpg_pdf_path_list=()

known_empty_png_sizes=""

# reference files are in empty-pages/
# known hashes are more reliable than known sizes
# so we can permanently store hashes of empty pngs
known_empty_png_hashes="7a3abefeea6a3be49afaaf895d945e9da962313d49932c01be6c9a2fc3546eb0"

page_output_pdf_path_list=()



# TODO parse ranges of pages
#for page in $(seq 1 $num_pages); do
#for page in 38; do
#for page in $(seq 38 48); do
#for page in $(seq 38 40); do
#for page_number in $(seq 46 47); do
#for page_number in $(seq 46 100); do
#for page_number in $(seq 60 100); do
#for page_number in $(seq 61 62); do
#for page_number in 60; do
#for page_number in 1; do

# loop pages

for page_number in $(seq $first_page $last_page); do

  echo
  echo page $page_number

  page_number_pad=$(printf "$page_number_pad_fmt" $page_number)

  # multi-page PDF to single-page PDF
  #page_pdf_path=$tempdir/$page_base_path.input.pdf
  page_pdf_path=$tempdir/page-$page_number_pad.input.pdf
  #echo "input pdf path: $page_pdf_path"

  # no need for pdfselect. also, the "page size error" is worse than with gs
  #pdfselect --pages $page_number --outfile $page_pdf_path "$input_pdf_path" >/dev/null
  gs -q -sDEVICE=pdfwrite -o $page_pdf_path -dFirstPage=$page_number -dLastPage=$page_number "$input_pdf_path"

  # FIXME rename to page_pdf_*
  page_pdf_size=$(stat -c%s $page_pdf_path)
  echo "page pdf size: $page_pdf_size"

  # FIXME gs produces slightly wrong pdf page sizes
  # expected: 419.527 x 637.793 pts
  # actual:   419.53 x 637.79 pts

  page_vectors_pdf_path=$tempdir/page-$page_number_pad.input-vectors.pdf
  gs -q -o $page_vectors_pdf_path -sDEVICE=pdfwrite -dFILTERIMAGE -dFILTERTEXT $page_pdf_path

  page_vectors_pdf_size=$(stat -c%s $page_vectors_pdf_path)
  echo "page vectors pdf size: $page_vectors_pdf_size"


  # no. extracting one page pdf from a multi-page pdf
  # gives a pdf with different page size than the original pdf.
  # this happens with: pdfselect, gs
  # ideally, "extracting one page pdf from a multi-page pdf" would be lossless
  #read page_pdf_width page_pdf_height < <(pdfinfo $page_pdf_path | grep "^Page size:" | sed 's/pts$/pt/' | awk '{ print $3 $6" "$5 $6 }')
  read page_pdf_width page_pdf_height < <(
    pdfinfo -f $page_number -l $page_number "$input_pdf_path" |
    grep -E "^Page .* size:" |
    sed 's/pts/pt/' |
    awk '{ print $4 $7" "$6 $7 }'
  )
  # example: 419.527pt 637.788pt

  echo "page pdf width: $page_pdf_width"
  echo "page pdf height: $page_pdf_height"
  if ! echo "$page_pdf_width" | grep -q -E "pts?$"; then
    echo "error: expected page width and height in pt or pts units, got width '$page_pdf_width' and height '$page_pdf_height' from 'pdfinfo $page_pdf_path'"
    exit 1
  fi
  page_pdf_width_pt=$(echo $page_pdf_width | sed -E 's/pts?$//')
  page_pdf_height_pt=$(echo $page_pdf_height | sed -E 's/pts?$//')
  # example: 419.527 637.788

  if ((page_vectors_pdf_size < page_vectors_pdf_size_min)); then
    echo "skipping page because vectors are small"
    # add empty pdf page
    empty_pdf_path=$tempdir/empty-page.${page_pdf_width}x${page_pdf_height}.pdf
    if ! [ -e $empty_pdf_path ]; then
      # TODO remove later, after combining all PDF pages
      convert -size ${page_pdf_width_pt}x${page_pdf_height_pt} xc:white $empty_pdf_path
    fi
    jp2_pdf_path_list+=($empty_pdf_path)
    continue
  fi

  page_novectors_pdf_path=$tempdir/page-$page_number_pad.input-novectors.pdf
  gs -q -o $page_novectors_pdf_path -sDEVICE=pdfwrite -dFILTERVECTOR $page_pdf_path



  # loop resolutions
  # TODO remove

  #for resolution in 600 300 150 75 72; do
  #for resolution in 600 300 150; do
  #for resolution in 600; do # i want 600dpi for printing (1200dpi would be too much)
  for resolution in $images_resolution; do # i want 600dpi for printing (1200dpi would be too much)

    resolution_pad=$(printf "%04i" $resolution)

    page_base_path=$tempdir/page-$page_number_pad-${resolution_pad}dpi

    # TODO filter by $page_pdf_size - skip small pages

    page_png_path=
    if true; then
      # PDF vector image to png raster image
      # needed for jpg
      #pdftoppm "$input_pdf_path" $page_base_path -f $page_number -singlefile -r $resolution
      #pdftoppm -png $page_vectors_pdf_path $page_vectors_pdf_path.${resolution}dpi -f 1 -singlefile -r $resolution
      #pdftocairo -png $page_vectors_pdf_path $page_vectors_pdf_path.${resolution}dpi -f 1 -singlefile -r $resolution
      # TODO fix all other pdftocairo calls: move all options to the left
      pdftocairo -png -f 1 -singlefile -r $resolution $page_vectors_pdf_path $page_vectors_pdf_path.${resolution}dpi
      page_png_path=$page_vectors_pdf_path.${resolution}dpi.png
      #echo "page png path: $page_png_path"
      page_png_size=$(stat -c%s $page_png_path)
      echo "page png size: $page_png_size"
      # sha256 is fast, so it does not hurt
      page_png_hash=$(sha256sum $page_png_path | cut -c1-64)
      #echo "page png hash: $page_png_hash"
      page_png_width_height=$(identify -format "%wx%h" $page_png_path)
      echo "page png bbox: $page_png_width_height"
      read page_png_width page_png_height < <(echo "$page_png_width_height" | tr 'x' ' ')
    fi

    # detect and skip empty pages
    # https://superuser.com/questions/343385/detecting-blank-image-files
    if ((page_png_size < page_png_size_min)); then
      if
        # fast path: check the file size
        [[ " $known_empty_png_sizes " =~ " $page_png_size " ]] ||
        # fast path: check the file hash
        [[ " $known_empty_png_hashes " =~ " $page_png_hash " ]] ||
        # slow path: get the color count
        [[ "$(identify -format %k $page_png_path)" == 1 ]]
      then
        # png is white -> pdf page is empty -> generate empty output page
        # FIXME avoid. when the onlyvectors page is empty, just keep the original page, dont merge
        # FIXME convert rounds float sizes into int sizes
        echo "page $page_number is empty"
        empty_pdf_path=$tempdir/empty-page.${page_pdf_width}x${page_pdf_height}.pdf
        if ! [ -e $empty_pdf_path ]; then
          # TODO remove later, after combining all PDF pages
          convert -size ${page_pdf_width_pt}x${page_pdf_height_pt} xc:white $empty_pdf_path
        fi
        jp2_pdf_path_list+=($empty_pdf_path)
        if ! [[ " $known_empty_png_sizes " =~ " $page_png_size " ]]; then
          known_empty_png_sizes+=" $page_png_size"
        fi
        if ! [[ " $known_empty_png_hashes " =~ " $page_png_hash " ]]; then
          known_empty_png_hashes+=" $page_png_hash"
        fi
        # stop looping resolutions, continue with next page
        # TODO restore
        #rm $page_png_path
        break
      fi
    fi



    # the JP2 compressor is "confused" by the large white space on pages 46 47.
    # fix: we first extract multiple small images ("subimages") from every page, and then compress
    # https://stackoverflow.com/questions/64046602/how-can-i-crop-an-object-from-surrounding-white-background-in-python-numpy
    # https://stackoverflow.com/questions/49683091/how-to-extract-photos-from-jpg-with-white-background
    #   convert page-046-0600dpi.png -blur 20x20 -threshold 99% -connected-components 4 null:

    # extract multiple small images from page
    # relative to a white background

    # get bounding boxes of objects on page
    # example: 216x320+3281+649

    #page_width_height=$(identify -format "%wx%h" $page_png_path)
    # TODO use a more complex strategy for threshold?
    # currently we assume a "perfect white" background, so we can simply use "-threshold 99%"
    # scan.sh:
    #lowthresh=40 # higher = more black, more artefacts
    #highthresh=80 # lower = more white, artefacts
    #postprocess_options+=( -black-threshold "${lowthresh}%" -white-threshold "${highthresh}%" -level ${lowthresh}x${highthresh}% )

    page_objects_blur=40x40
    page_objects_blur=0x0 # debug: objects are black squares

    page_objects_black_threshold=99%

    # https://imagemagick.org/script/connected-components.php
    # to detect unique objects without overlap, we use: grep -E " gray\(0\)| srgb\(0,0,0\)$"
    # wanted objects have color "gray(0)" or "srgb(0,0,0)" (TODO more?)
    # unwanted objects have color "gray(255)" or "srgb(255,255,255)" (TODO more?)

    # done
    # FIXME this is slow. make this faster by using a lower resolution like 150dpi
    # and then scaling all bbox values by 4

    # done, avoid "scale_x versus scale_y detection"
    # FIXME this breaks the scale_x versus scale_y detection
    # because the images have a slightly different width and height
    # no?!
    #page_objects_resolution=150
    #page_objects_resolution=600

    #page_objects_downscale_factor=1 # slow at "convert -connected-components 4"
    page_objects_downscale_factor=4

    echo "page objects downscale factor: $page_objects_downscale_factor"

    page_objects_resolution=$(echo "scale=20; $resolution / $page_objects_downscale_factor" | bc | sed -E 's/\.0+$//')

    echo "page objects resolution: $page_objects_resolution"

    # assert integer result
    if ! echo "$page_objects_resolution" | grep -q -E "^[0-9]+$"; then
      echo "failed to get integer page_objects_resolution from resolution = $resolution -- actual value: $page_objects_resolution"
      exit 1
    fi

    if (( page_objects_downscale_factor > 1 )); then
      # no? wrong output size?
      # page_png_path=$page_vectors_pdf_path.${resolution}dpi.png
      if false; then
        # TODO assert integer result
        page_objects_resolution=$((resolution / page_objects_downscale_factor))
        page_objects_page_png_path=$page_png_path.${page_objects_resolution}dpi.png
        convert $page_png_path -scale $((100 / page_objects_downscale_factor))% $page_objects_page_png_path
      fi
      #pdftoppm -png $page_vectors_pdf_path $page_vectors_pdf_path.${page_objects_resolution}dpi -f 1 -singlefile -r $page_objects_resolution
      pdftocairo -png $page_vectors_pdf_path $page_vectors_pdf_path.${page_objects_resolution}dpi -f 1 -singlefile -r $page_objects_resolution
      page_objects_page_png_path=$page_vectors_pdf_path.${page_objects_resolution}dpi.png
    else
      page_objects_page_png_path=$page_png_path
    fi

    #if false; then
    if true; then
      # debug
      page_png_debug_object_detection_path=$page_base_path.debug-object-detection.png
      echo "writing $page_png_debug_object_detection_path"
      convert $page_objects_page_png_path -blur $page_objects_blur -threshold $page_objects_black_threshold $page_png_debug_object_detection_path
    fi

    # convert -connected-components 4

    page_objects_args=(
      -blur $page_objects_blur
      -threshold $page_objects_black_threshold
      -define connected-components:exclude-header=true
      -define connected-components:verbose=true
      -define connected-components:area-threshold=400
      -connected-components 4
      null:
    )

    object_components="$(convert $page_objects_page_png_path "${page_objects_args[@]}")"
    echo "object components:"
    echo "$object_components"

    # grep -v "  0: " # ignore the "root object" which is the full page

    object_bbox_list=( $(echo "$object_components" | grep -v "  0: " | grep -E " gray\(0\)| srgb\(0,0,0\)$" | awk '{ print $2 }') )

    object_jp2_path_list=()
    object_jp2_pdf_path_list=()

    echo "object_bbox_list before scaling: ${object_bbox_list[@]}"

    if (( page_objects_downscale_factor > 1 )); then
      for object_idx in ${!object_bbox_list[@]}; do
        object_bbox=${object_bbox_list[object_idx]}
        if ! echo "$object_bbox" | grep -q -E "^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$"; then
          echo "error: unexpected bbox format in object_bbox '$object_bbox'"
          exit 1
        fi
        read object_bbox_x object_bbox_y object_bbox_l object_bbox_t < <(echo "$object_bbox" | tr '[x+]' ' ')
        object_bbox_x=$((object_bbox_x * page_objects_downscale_factor))
        object_bbox_y=$((object_bbox_y * page_objects_downscale_factor))
        object_bbox_l=$((object_bbox_l * page_objects_downscale_factor))
        object_bbox_t=$((object_bbox_t * page_objects_downscale_factor))
        object_bbox="${object_bbox_x}x${object_bbox_y}+${object_bbox_l}+${object_bbox_t}"
        object_bbox_list[$object_idx]="$object_bbox"
      done
    fi

    echo "object_bbox_list after scaling: ${object_bbox_list[@]}"

    for object_idx in ${!object_bbox_list[@]}; do

      object_base_path=$page_base_path-object${object_idx}

      # TODO get object_pdf_path to filter objects by size
      # pdftk? gs? pdfjam?
      # some pages can contain
      # a mix of small vectors graphics and large vectors graphics
      # we want to compress only the large vectors graphics

      # TODO delete later
      object_png_path=$object_base_path.png
      object_bbox=${object_bbox_list[object_idx]}
      convert -density $resolution -units pixelsperinch $page_png_path -crop $object_bbox +repage $object_png_path

      echo "object bbox: $object_bbox"

      if ! echo "$object_bbox" | grep -q -E "^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$"; then
        echo "error: unexpected bbox format in object_bbox '$object_bbox'"
        exit 1
      fi

      read object_bbox_x object_bbox_y object_bbox_l object_bbox_t < <(echo "$object_bbox" | tr '[x+]' ' ')

      if true; then
      echo "object bbox x: $object_bbox_x"
      echo "object bbox y: $object_bbox_y"
      echo "object bbox l: $object_bbox_l"
      echo "object bbox t: $object_bbox_t"
      fi

      if false; then
      #if true; then
        #for jpg_quality in 5 10 15 20 25 30 40 50; do
        # jpg q20 looks okay but is too large with 200KB
        #for jpg_quality in 10 20 30 40 50; do
        #for jpg_quality in $(seq 30 50); do # TODO micro optimize, try to reduce q40
        for jpg_quality in 40; do
          # PPM raster image to JPG raster image
          jpg_path=$object_base_path.q$jpg_quality.jpg
          jpg_pdf_path=$object_base_path.q$jpg_quality.jpg.pdf
          jpg_pdf_path_list+=($jpg_pdf_path)
          echo "jpg path: $jpg_path"
          convert $object_png_path -quality $jpg_quality $jpg_path
          jpg_size=$(stat -c%s $jpg_path)
          echo "jpg size: $jpg_size"
          # img2pdf result is slightly smaller than imagemagick result
          # 348581  page-038-0600dpi.q40.jpg.img2pdf.pdf
          # 349425  page-038-0600dpi.q40.jpg.imagemagick.pdf
          #convert $jpg_path $jpg_pdf_path
          img2pdf -o $jpg_pdf_path $jpg_path
          rm $jpg_path
        done
      fi

      # TODO why is jp2 smaller than jpg, but jp2.pdf larger than jpg.pdf
      # blame imagemagick?
      # https://unix.stackexchange.com/questions/42856/how-can-i-convert-a-png-to-a-pdf-in-high-quality-so-its-not-blurry-or-fuzzy
      #   img2pdf -o sample.pdf sample.jp2

      # 1205606 page-038.input.pdf
      # 1165486 page-038-0600dpi.png

      # 229916  page-038-0600dpi.q20.jpg
      # 79500   page-038-0600dpi.q40.jp2 # winner by factor 2.9 over jpg

      # note: imagemagick ("convert") fails to embed JP2 into PDF, so we use img2pdf
      # 80967   page-038-0600dpi.q40.jp2.img2pdf.pdf # 14.9x smaller than innput pdf
      # 232759  page-038-0600dpi.q20.jpg.pdf # winner by factor 2.6 over jp2 # 5.2x smaller than input pdf
      # 605639  page-038-0600dpi.q40.jp2.imagemagick.pdf # 2.0x smaller than input pdf

      # JPEG 2000
      # higher compression than JPEG
      # higher memory usage than JPEG
      # less popular than JPEG = less compatibilty than JPEG
      # https://www.adobe.com/creativecloud/file-types/image/comparison/jpeg-vs-jpeg-2000.html
      #for jp2_quality in 5 10 15 20 25 30 40 50; do
      #for jp2_quality in 10 20 30 40 50; do # up to q35 is horrible, q40 looks okay

      # FIXME q39 looks bad on some pages! pages 46 47 of "Stephen R. Covey - Die 7 Wege zu glücklichen Beziehungen. 2021.pdf" (70MB)
      # jp2 q40 looks okay
      # jp2 q39 looks okay too, its "practically lossless" compared to the orignal PDF.
      # jp2 q38 starts to have broken contour lines
      # jp2 q36 starts to get blurry
      # jp2 q45 is 3x larger than q40, but only 1% prettier...

      # 15388   page-038-0600dpi.q35.jp2
      # 22100   page-038-0600dpi.q36.jp2
      # 29943   page-038-0600dpi.q37.jp2
      # 43474   page-038-0600dpi.q38.jp2 # ugly

      # 60133   page-038-0600dpi.q39.jp2 # pretty
      # 79500   page-038-0600dpi.q40.jp2
      # 104912  page-038-0600dpi.q41.jp2
      # 136423  page-038-0600dpi.q42.jp2
      # 170518  page-038-0600dpi.q43.jp2
      # 204006  page-038-0600dpi.q44.jp2
      # 236237  page-038-0600dpi.q45.jp2



      # loop jp2 quality

      #for jp2_quality in 40 45 50 55 60; do
      #for jp2_quality in $(seq 35 45); do
      #for jp2_quality in 39; do # blurry compared to PNG
      for jp2_quality in 50; do
      #for jp2_quality in 60; do # still blurry...
      #for jp2_quality in 100; do # still blurry! wtf?
      # FIXME output is blurry
      #for jp2_quality in $(seq $jp2_quality_min $jp2_quality_inc $jp2_quality_max); do

        # PPM raster image to jp2 raster image
        # TODO delete later
        # TODO rename to object_jp2_path
        jp2_path=$object_base_path.q$jp2_quality.jp2
        #jp2_path_list+=($jp2_path)
        jp2_pdf_path=$object_base_path.q$jp2_quality.jp2.pdf

        if false; then
        # TODO later, filter by quality
        #jp2_pdf_path_list+=($jp2_pdf_path)
        #echo "jp2 path: $jp2_path"
        #echo "jp2 pdf path: $jp2_pdf_path"
        convert -density $resolution -units pixelsperinch $object_png_path -quality $jp2_quality $jp2_path
        jp2_size=$(stat -c%s $jp2_path)
        echo "jp2 size: $jp2_size"
        else
        # use png instead of jp2
        jp2_path=$object_png_path
        fi

        # embed in pdf to make the jp2 viewable in a web browser
        # no! imagemagick fails to embed JP2 into PDF, the output PDF is much larger than expected
        #convert $jp2_path $jp2_pdf_path
        # TODO use ghostscript?
        # FIXME img2pdf creates blurry pdf from sharp jp2 image
        # use gimp to view the jp2 image
        # same problem with png images:
        # img2pdf creates blurry pdf from sharp png image
        # TODO set --pagesize and --imgsize
        # then the image is centered, so we still need "pdfjam --offset"
        # img2pdf page-061-0600dpi-object0.png -o page-061-0600dpi-object0.png.test.pdf --engine pikepdf  --pagesize 419.527ptx637.793pt --imgsize 89.25595882184729ptx
        # https://tex.stackexchange.com/questions/1162/included-png-appears-blurry-in-pdf
        #   increase the resolution of png and/or pdf
        # https://tex.stackexchange.com/questions/38555/image-quality-using-pdflatex
        #   use vector graphics
        # https://graphicdesign.stackexchange.com/questions/107888/check-dpi-of-png-file
        #   png images have an optional DPI header
        # https://stackoverflow.com/questions/1551532/setting-dpi-for-png-files
        #   convert -density 300 -units pixelsperinch infile.jpg outfile.png
        # maybe blame my display scaling of 150%? but still, the images should be sharp
        # blame the chrome PDF reader. images look better in the okular PDF reader

        # no. later use pdflatex
        if false; then

          img2pdf -o $jp2_pdf_path $jp2_path
          object_bbox_offset_x=$(echo $object_bbox | sed -E 's/^[0-9]+x[0-9]+\+([0-9]+)\+([0-9]+)/\1/')
          object_bbox_offset_y=$(echo $object_bbox | sed -E 's/^[0-9]+x[0-9]+\+([0-9]+)\+([0-9]+)/\2/')
          # apply offset, expand page
          # TODO delete later
          jp2_pdf_path_bak=$object_base_path.q$jp2_quality.jp2.bak.1.pdf
          mv $jp2_pdf_path $jp2_pdf_path_bak

          # scale_x versus scale_y detection
          # some images are scaled by their x coordinates
          # some images are scaled by their y coordinates
          # TODO why?!

          # TODO set resolution to 600dpi?
          # TODO quiet
          # FIXME position is wrong
          # https://superuser.com/questions/904332/add-gutter-binding-margin-to-existing-pdf-file
          # https://stackoverflow.com/questions/7973823/how-do-you-shift-all-pages-of-a-pdf-document-right-by-one-inch
          #
          # page png bbox: 3497x5315
          # object bbox: 216x320+3281+649
          #
          # input pdf size:
          # $ pdfinfo page-046.input.pdf | grep "Page size"
          # Page size:       419.527 x 637.788 pts
          #
          # actual output pdf size:
          # $ pdfinfo  page-046-0600dpi-object0.q39.jp2.bak.pdf  | grep "Page size"
          # Page size:       162 x 240 pts
          # 216 / 162 = 1.3333333333
          #
          # expected output pdf size:
          # 216 / 3497 * 419.527 = 25.913020303116955
          # 25.913020303116955 / 162 = 0.15995691545133922 = about 0.16
          # 162 / 25.913020303116955 = 6.251683443497082 = about 6.25
          # -> 6.25x smaller
          #
          # 216 / 6.25 = 34.56
          # 162 / 6.25 = 25.92
          # no: gs -q -o output.pdf -sDEVICE=pdfwrite -dDEVICEWIDTHPOINTS=34.56 -dDEVICEHEIGHTPOINTS=25.92 -g34970x53150 -r600x600 -dBATCH -dSAFER -c "<</PageOffset [0 0]>>setpagedevice" -f page-046-0600dpi-object0.q39.jp2.bak.pdf

          # https://stackoverflow.com/questions/20235541/add-a-pdf-file-png-basically-to-the-end-of-every-page-in-another-pdf-file

          # almost perfect:
          # pdfjam --papersize '{419.527pt,637.788pt}' --scale 0.061 --offset '196.95pt 221.82pt' --outfile output.pdf page-046-0600dpi-object0.q39.jp2.bak.pdf
          # but how do i get the numbers for scale and offset?
          # without offset, the image is placed at the page center

          # this moves the image to the top-left corner of the page
          # pdfjam --papersize '{419.527pt,637.788pt}' --scale 0.061 --offset '-195pt 300pt' --outfile output.pdf page-046-0600dpi-object0.q39.jp2.bak.pdf

          # 419.527 / 2 = 209.7635
          # 637.788 / 2 = 318.894

          # 209.7635 - 195 = 14.7635
          # 318.894 - 300 = 18.894

          # now, how do i get 14.7635 and 18.894 from the image size 216x320

          # 216 / 14.7635 = 14.630677007484675
          # 320 / 18.894 = 16.936593627606648
          # -> too different...
          # average: 16
          # 216 / 16 = 13.5
          # 320 / 16 = 20

          # 209.7635 - 13.5 = 196.2635
          # 318.894 - 20 = 298.894
          # try:
          # pdfjam --papersize '{419.527pt,637.788pt}' --scale 0.061 --offset '-196.2635pt 298.894pt' --outfile output.pdf page-046-0600dpi-object0.q39.jp2.bak.pdf
          # yes...
          # debug: add "--frame True" -> the frame must disappear exactly on the top-left corner
          # better guess: -196.8pt instead of -196.2635pt
          # 209.7635 - 196.8 = 12.963499999999982
          # 216 / 12.963499999999982 = 16.662166853087538
          # aah! lets use 16.66666666666 = 100 / 6

          # 216 / (100 / 6) = 12.959999999999999 = 12.96
          # 320 / (100 / 6) = 19.2

          # 209.7635 - 12.96 = 196.80349999999999 = 196.8035
          # 318.894 - 19.2 = 299.694

          # pdfjam --papersize '{419.527pt,637.788pt}' --scale 0.061 --offset '-196.8035pt 299.694pt' --outfile output.pdf page-046-0600dpi-object0.q39.jp2.bak.pdf
          # perfect!



          # 2.

          # now how do i get from '-196.8035pt 299.694pt' to '196.95pt 221.82pt'
          # both x and y differences must be positive, to match the pixel offset "+3281+649"

          # 196.95 - (-196.8035) = 393.7535
          # -1*(221.82 - 299.694) = 77.874

          # page png bbox: 3497x5315
          # object bbox: 216x320+3281+649

          # 3281 / 393.7535 = 8.332624344926458
          # 649 / 77.874 = 8.333975396152761

          # 8.33333333333333333333 = 25 / 3 = 100 / 12

          # okay:
          # '-196.8035pt 299.694pt' is the top-left corner
          # -196.8035 + (3281 / (100 / 12)) = 196.9165
          # 299.694 - (649 / (100 / 12)) = 221.814

          # pdfjam --papersize '{419.527pt,637.788pt}' --scale 0.061 --offset '196.9165pt 221.814pt' --outfile output.pdf page-046-0600dpi-object0.q39.jp2.bak.pdf
          # almost perfect! the scaling should be slightly bigger like 0.06115, so...
          # pdfjam --papersize '{419.527pt,637.788pt}' --scale 0.06115 --offset '196.9165pt 221.814pt' --outfile output.pdf page-046-0600dpi-object0.q39.jp2.bak.pdf



          # 1. move the image from center to the top-left corner
          # -1*(($page_pdf_width_pt / 2) - ($object_bbox_x / (100 / 6))) = -196.8035
          # ($page_pdf_height_pt / 2) - ($object_bbox_y / (100 / 6)) = 299.694

          # 2. move the image from the top-left corner to its expected position
          # (-1*(($page_pdf_width_pt / 2) - ($object_bbox_x / (100 / 6)))) + ($object_bbox_l / (100 / 12)) = 196.9165
          # ($page_pdf_height_pt / 2) - ($object_bbox_y / (100 / 6)) - ($object_bbox_t / (100 / 12)) = 221.814
          # TODO simplify formula to increase precision

          pdfjam_offset_x=$(echo "scale=$float_precision_digits; (-1*(($page_pdf_width_pt / 2) - ($object_bbox_x / (100 / 6)))) + ($object_bbox_l / (100 / 12))" | bc)
          pdfjam_offset_y=$(echo "scale=$float_precision_digits; ($page_pdf_height_pt / 2) - ($object_bbox_y / (100 / 6)) - ($object_bbox_t / (100 / 12))" | bc)

          echo "pdfjam offset x: $pdfjam_offset_x"
          echo "pdfjam offset y: $pdfjam_offset_y"

          # no. "--scale 0.06115" depends on the input size
          #pdfjam --papersize "{$page_pdf_width,$page_pdf_height}" --scale 0.06115 --offset "${pdfjam_offset_x}pt ${pdfjam_offset_y}pt" --outfile $jp2_pdf_path $jp2_pdf_path_bak
          #
          # page 46
          # page pdf width: 419.527pt
          # page pdf height: 637.793pt
          # page png bbox: 3497x5315
          # object bbox: 216x311+3281+657
          # pdfjam  scale: 0.06115 (manual)
          # pdfjam scale x: .06176722905347440663
          # pdfjam scale y: .05851364063969896519
          #
          # 216 / 3497 = 0.061767229053474405 (close)
          # 311 / 5315 = 0.058513640639698966
          #
          # (0.061767229053474405 + 0.058513640639698966) / 2 = 0.06014043484658668 (close)
          #
          # 216 / 0.06115 = 3532.297628781684 (close)
          # 311 / 0.06115 = 5085.854456255111

          # page 47
          # page pdf width: 419.527pt
          # page pdf height: 637.793pt
          # page png bbox: 3497x5315
          # object bbox: 561x1232+0+541
          # pdfjam scale: 0.231 (manual)
          # pdfjam scale x: .16042321990277380611
          # pdfjam scale y: .23179680150517403574 # perfect
          #
          # 561 / 3497 = 0.1604232199027738
          # 1232 / 5315 = 0.23179680150517404 (close)
          #
          # (0.1604232199027738 + 0.23179680150517404) / 2 = 0.19611001070397394 (no)
          #
          # 561 / 0.231 = 2428.5714285714284
          # 1232 / 0.231 = 5333.333333333333 (close)

          # page_png_width page_png_height

          # TODO rename "object_bbox_x" to "object_width_px"
          # TODO rename "object_bbox_y" to "object_height_px"
          # TODO rename "object_bbox_l" to "object_left_px"
          # TODO rename "object_bbox_t" to "object_top_px"

          pdfjam_scale_x=$(echo "scale=$float_precision_digits; $object_bbox_x / $page_png_width" | bc)
          pdfjam_scale_y=$(echo "scale=$float_precision_digits; $object_bbox_y / $page_png_height" | bc)
          echo "pdfjam scale x: $pdfjam_scale_x"
          echo "pdfjam scale y: $pdfjam_scale_y"

          # using the average value is definitely wrong.
          # its either $pdfjam_scale_x or $pdfjam_scale_y
          # but i dont know how its decided yet...
          # so i try both and compare the rendered png images
          #pdfjam_scale=$(echo "scale=$float_precision_digits; (($object_bbox_x / $page_png_width) + ($object_bbox_y / $page_png_height)) / 2" | bc)

          #pdfjam_scale=$pdfjam_scale_y
          #echo "pdfjam scale: $pdfjam_scale"

          # use lower resolution to make diff faster
          diff_resolution=150

          jp2_pdf_path_scale_x=$object_base_path.q$jp2_quality.jp2.scale-x.pdf
          jp2_pdf_path_scale_y=$object_base_path.q$jp2_quality.jp2.scale-y.pdf

          # fixed by using "bp" instead of "pt" units
          if false; then
          #if true; then
          # "pdfjam --papersize" produces wrong pdf page sizes
          # TODO issue https://github.com/rrthomas/pdfjam/issues/new
          # does pdfjam add some border to the pdf page?
          # TODO assert same pdf page size via pdfinfo
          pdfjam_papersize_factor=1.0037491626
          pdfjam_papersize_x=$(echo "scale=20; $page_pdf_width_pt * $pdfjam_papersize_factor" | bc)pt
          pdfjam_papersize_y=$(echo "scale=20; $page_pdf_height_pt * $pdfjam_papersize_factor" | bc)pt
          echo "using patched pdfjam papersize: $pdfjam_papersize_x,$pdfjam_papersize_y"
          #pdfjam_args=(pdfjam --papersize "{$page_pdf_width,$page_pdf_height}" --scale $pdfjam_scale_x --offset "${pdfjam_offset_x}pt ${pdfjam_offset_y}pt" --outfile $jp2_pdf_path_scale_x $jp2_pdf_path_bak)
          pdfjam_args=(pdfjam --papersize "{$pdfjam_papersize_x,$pdfjam_papersize_y}" --scale $pdfjam_scale_x --offset "${pdfjam_offset_x}pt ${pdfjam_offset_y}pt" --outfile $jp2_pdf_path_scale_x $jp2_pdf_path_bak)
          else
          # note: pdfinfo "pt" unit -> pdfjam "bp"
          # https://github.com/rrthomas/pdfjam/issues/68
          # TODO? replace pdfjam with https://github.com/rrthomas/psutils
          # ... written in python, but i want to move to python anyway
          #pdfjam_args=(pdfjam --papersize "{${page_pdf_width_pt}bp,${page_pdf_height_pt}bp}" --scale $pdfjam_scale_x --offset "${pdfjam_offset_x}pt ${pdfjam_offset_y}pt" --outfile $jp2_pdf_path_scale_x $jp2_pdf_path_bak)
          pdfjam_args=(pdfjam --papersize "{${page_pdf_width_pt}bp,${page_pdf_height_pt}bp}" --scale $pdfjam_scale_x --offset "${pdfjam_offset_x}bp ${pdfjam_offset_y}bp" --outfile $jp2_pdf_path_scale_x $jp2_pdf_path_bak)
          # TODO how do we get offset values?
          fi

          echo -n '$'; for a in "${pdfjam_args[@]}"; do echo -n " ${a@Q}"; done; echo # debug
          if ! pdfjam_output=$("${pdfjam_args[@]}" 2>&1); then
            echo "error: pdfjam failed to fix the image pdf size"
            echo "$pdfjam_output"
            exit 1
          fi
          #pdftoppm -png $jp2_pdf_path_scale_x $jp2_pdf_path_scale_x.${diff_resolution}dpi -f 1 -singlefile -r $diff_resolution
          pdftocairo -png $jp2_pdf_path_scale_x $jp2_pdf_path_scale_x.${diff_resolution}dpi -f 1 -singlefile -r $diff_resolution
          jp2_png_path_scale_x=$jp2_pdf_path_scale_x.${diff_resolution}dpi.png

          #pdfjam_args=(pdfjam --papersize "{$page_pdf_width,$page_pdf_height}" --scale $pdfjam_scale_y --offset "${pdfjam_offset_x}pt ${pdfjam_offset_y}pt" --outfile $jp2_pdf_path_scale_y $jp2_pdf_path_bak)
          #pdfjam_args=(pdfjam --papersize "{$pdfjam_papersize_x,$pdfjam_papersize_y}" --scale $pdfjam_scale_y --offset "${pdfjam_offset_x}pt ${pdfjam_offset_y}pt" --outfile $jp2_pdf_path_scale_y $jp2_pdf_path_bak)
          #pdfjam_args=(pdfjam --papersize "{${page_pdf_width_pt}bp,${page_pdf_height_pt}bp}" --scale $pdfjam_scale_y --offset "${pdfjam_offset_x}pt ${pdfjam_offset_y}pt" --outfile $jp2_pdf_path_scale_y $jp2_pdf_path_bak)
          pdfjam_args=(pdfjam --papersize "{${page_pdf_width_pt}bp,${page_pdf_height_pt}bp}" --scale $pdfjam_scale_y --offset "${pdfjam_offset_x}bp ${pdfjam_offset_y}bp" --outfile $jp2_pdf_path_scale_y $jp2_pdf_path_bak)
          echo -n '$'; for a in "${pdfjam_args[@]}"; do echo -n " ${a@Q}"; done; echo # debug
          if ! pdfjam_output=$("${pdfjam_args[@]}" 2>&1); then
            echo "error: pdfjam failed to fix the image pdf size"
            echo "$pdfjam_output"
            exit 1
          fi
          #pdftoppm -png $jp2_pdf_path_scale_y $jp2_pdf_path_scale_y.${diff_resolution}dpi -f 1 -singlefile -r $diff_resolution
          pdftocairo -png $jp2_pdf_path_scale_y $jp2_pdf_path_scale_y.${diff_resolution}dpi -f 1 -singlefile -r $diff_resolution
          jp2_png_path_scale_y=$jp2_pdf_path_scale_y.${diff_resolution}dpi.png

          #pdftoppm -png $page_vectors_pdf_path $page_vectors_pdf_path.${diff_resolution}dpi -f 1 -singlefile -r $diff_resolution
          pdftocairo -png $page_vectors_pdf_path $page_vectors_pdf_path.${diff_resolution}dpi -f 1 -singlefile -r $diff_resolution
          page_vectors_png_path=$page_vectors_pdf_path.${diff_resolution}dpi.png

          # FIXME image sizes: all these images should have the same size
          # $ identify *.150dpi.png
          # page-060-0600dpi-object0.q39.jp2.scale-x.pdf.150dpi.png PNG 871x1324 871x1324+0+0 8-bit sRGB 240587B 0.000u 0:00.000
          # page-060-0600dpi-object0.q39.jp2.scale-y.pdf.150dpi.png PNG 871x1324 871x1324+0+0 8-bit sRGB 240397B 0.000u 0:00.000
          # page-060.input-vectors.pdf.150dpi.png PNG 875x1329 875x1329+0+0 8-bit sRGB 199101B 0.000u 0:00.000
          # page-060.input-vectors.pdf.600dpi.png.150dpi.png PNG 874x1329 874x1329+0+0 8-bit Grayscale Gray 256c 146579B 0.000u 0:00.000

          # FIXME pdf files have different pages sizes
          # blame pdfjame?
          # https://duckduckgo.com/?q=pdfjam+wrong+papersize+pdfinfo
          # https://superuser.com/questions/1584106/scale-pdf-to-exact-size
          #
          # page-060-0600dpi-object0.q39.jp2.scale-y.pdf
          # ++ pdfjam --papersize '{419.527pt,637.793pt}' --scale .86622765757290686735 --offset '8.15650000000000000008pt -42.78350000000000000014pt' --outfile /run/user/1000/tmp.mZfGZsxEHt-pdf-compress-vector-graphics/page-060-0600dpi-object0.q39.jp2.scale-y.pdf /run/user/1000/tmp.mZfGZsxEHt-pdf-compress-vector-graphics/page-060-0600dpi-object0.q39.jp2.bak.1.pdf
          #
          # for f in page-060.input.pdf page-060.input-vectors.pdf page-060-0600dpi-object0.q39.jp2.scale-x.pdf page-060-0600dpi-object0.q39.jp2.scale-y.pdf; do echo $f; pdfinfo $f | grep "Page size"; echo; done
          #
          # page-060.input.pdf
          # Page size:       419.527 x 637.793 pts
          #
          # page-060.input-vectors.pdf
          # Page size:       419.53 x 637.79 pts
          #
          # page-060-0600dpi-object0.q39.jp2.scale-x.pdf
          # Page size:       417.96 x 635.41 pts
          #
          # page-060-0600dpi-object0.q39.jp2.scale-y.pdf
          # Page size:       417.96 x 635.41 pts

          # no, this gives wrong results
          #if false; then
          if true; then
            # compare 3 png images, 2 should be very similar, 1 is an outlier
            # https://imagemagick.org/script/compare.php
            # TODO why does compare sometimes return 1?
            # FIXME fails to get output
            diff_scale_x="$(compare -verbose -metric mae $page_vectors_png_path $jp2_png_path_scale_x null: 2>&1 || true)"
            diff_scale_y="$(compare -verbose -metric mae $page_vectors_png_path $jp2_png_path_scale_y null: 2>&1 || true)"
            echo "diff_scale_x:"; echo "$diff_scale_x" # debug
            echo "diff_scale_y:"; echo "$diff_scale_y" # debug

            diff_scale_x_all=$(echo "$diff_scale_x" | grep "^    all:" | awk '{ print $2 }')
            diff_scale_y_all=$(echo "$diff_scale_y" | grep "^    all:" | awk '{ print $2 }')
            echo "diff_scale_x_all: $diff_scale_x_all" # debug
            echo "diff_scale_y_all: $diff_scale_y_all" # debug

            # FIXME what?
            # bigger value wins
            #diff_scale_winner=$(echo $diff_scale_x_all $diff_scale_y_all | awk '{ if ($1 > $2) print "x"; else print "y"; }')
            # smaller value wins
            diff_scale_winner=$(echo $diff_scale_x_all $diff_scale_y_all | awk '{ if ($1 < $2) print "x"; else print "y"; }')
            echo "diff_scale_winner: $diff_scale_winner" # debug

            if [[ "$diff_scale_winner" == "x" ]]; then
              cp $jp2_pdf_path_scale_x $jp2_pdf_path
            else
              cp $jp2_pdf_path_scale_y $jp2_pdf_path
            fi
          else
            # TODO connected-components
            page_objects_args=(
              -blur $page_objects_blur
              -threshold $page_objects_black_threshold
              -define connected-components:verbose=true
              -define connected-components:area-threshold=400
              -connected-components 4
              null:
            )

            object_components="$(convert $page_objects_page_png_path "${page_objects_args[@]}")"
            echo "object components:"
            echo "$object_components"

            object_bbox_list=( $(echo "$object_components" | tail -n +3 | grep -E " gray\(0\)| srgb\(0,0,0\)$" | awk '{ print $2 }') )
          fi

          if ! $keep_temp_files; then
            rm $jp2_pdf_path_scale_x
            rm $jp2_pdf_path_scale_y
            rm $jp2_png_path_scale_x
            rm $jp2_png_path_scale_y
            rm $page_vectors_png_path
          fi

        else
          :
        fi

        # fails...
        #gs -o $jp2_pdf_path -sDEVICE=pdfwrite -c "<< /PageOffset [$object_bbox_offset_x $object_bbox_offset_y] >> setpagedevice" -f $jp2_pdf_path_bak
        #pdfjam --papersize "{$page_pdf_width,$page_pdf_height}" --scale 0.061 --offset '196.95pt 221.82pt' --outfile $jp2_pdf_path $jp2_pdf_path_bak
        #jp2_pdf_size=$(stat -c%s $jp2_pdf_path)
        #echo "jp2 pdf size: $jp2_pdf_size"
        # we dont need the jp2 image any more
        # we only need jp2.pdf
        # TODO restore
        #rm $jp2_path

        #jp2_pdf_path_bak=$object_base_path.q$jp2_quality.jp2.bak.2.pdf
        #mv $jp2_pdf_path $jp2_pdf_path_bak

        object_jp2_path_list+=($jp2_path)
        object_jp2_pdf_path_list+=($jp2_pdf_path)

      done # loop jp2 quality



      ppm_path=
      if false; then
        # PDF vector image to PPM raster image
        # needed for autotrace
        #pdftoppm "$input_pdf_path" $page_base_path -f $page_number -singlefile -r $resolution
        #pdftoppm $page_vectors_pdf_path $page_vectors_pdf_path.${resolution}dpi -f 1 -singlefile -r $resolution
        pdftocairo $page_vectors_pdf_path $page_vectors_pdf_path.${resolution}dpi -f 1 -singlefile -r $resolution
        #ppm_path=$(find $tempdir -type f)
        #ppm_path=$(ls $page_base_path.*)
        ppm_path=$page_vectors_pdf_path.${resolution}dpi.ppm
        echo "ppm path: $ppm_path"
        ppm_size=$(stat -c%s $ppm_path)
        echo "ppm size: $ppm_size"
      fi

      #if true; then
      if false; then
        # PPM raster image to SVG vector image
        svg_path=$page_base_path.svg
        echo "svg path: $svg_path"
        #potrace --svg $ppm_path --progress --output $svg_path "${potrace_args[@]}"
        autotrace -report-progress -output-format svg -output-file $svg_path "${autotrace_args[@]}" $ppm_path
        svg_size=$(stat -c%s $svg_path)
        echo "svg size: $svg_size"
        # TODO filter by size, very small files are empty images
        # example: empty svg size: 526
        # TODO compress the SVG image
        #   https://jakearchibald.github.io/svgomg/
        # SVG vector image to PDF vector image
        # todo...
      fi

      #if true; then
      if false; then
        # PPM raster image to PDF vector image
        pdf_path=$page_base_path.pdf
        echo "pdf path: $pdf_path"
        #potrace --backend pdf --progress --output $pdf_path "${potrace_args[@]}" $ppm_path
        autotrace -report-progress -output-format pdf -output-file $pdf_path "${autotrace_args[@]}" $ppm_path
        pdf_size=$(stat -c%s $pdf_path)
        echo "pdf size: $pdf_size"
      fi

      #rm $ppm_path || true

      # debug: keep png
      #rm $object_png_path || true

    done



    # TODO produce transprent images?
    # does JP2 support transparency, or should we produce transprent PNG images?

    # no. img2pdf cant do this
    if false; then
    # TODO join all object images of this page into one PDF file
    # https://superuser.com/questions/879983/combining-multiple-pdf-fragments-to-one-page-top-aligned-without-margin
    # https://stackoverflow.com/questions/20846907/how-to-manage-image-placement-when-converting-to-pdf-with-imagemagick
    # https://github.com/ImageMagick/ImageMagick/discussions/3895 # How can I put multiple images per page in an A4 pdf file?
    # https://stackoverflow.com/questions/44542864/how-do-i-merge-multiple-images-into-one-with-exact-positions-and-sizes-to-create
    img2pdf_args=()
    #img2pdf_args+=(--engine pikepdf) # todo?
    # https://pikepdf.readthedocs.io/en/latest/topics/images.html
    # pikepdf currently has no facility to embed new images into PDFs.
    # We recommend img2pdf instead, because it does the job so well.
    # pikepdf instead allows for image inspection and lossless/transcode free (where possible) “pdf2img”.
    for object_idx in ${!object_bbox_list[@]}; do
      object_base_path=$page_base_path-object${object_idx}
      object_png_path=$object_base_path.png
      object_bbox=${object_bbox_list[object_idx]}
      # TODO set object position
      # convert object.png -gravity center -background white -extent "%[papersize:A4]" x.pdf
    done
    img2pdf_args+=(-o $page_output_pdf_path)
    img2pdf_args+=("${object_jp2_path_list[@]}")
    img2pdf "${img2pdf_args[@]}"
    fi

    # no. pdftk can stamp only one input file
    if false; then
    # no. the output.pdf is larger than the input.pdf
    # maybe pdftk converts the JP2 image to a JPG image...
    #if false; then
    # https://superuser.com/questions/452759/how-to-add-a-picture-onto-an-existing-pdf-file
    # object_jp2_pdf_path_list
    # object_jp2_path_list
    pdftk_args=()
    # loop objects
    for object_idx in ${!object_bbox_list[@]}; do
      #object_base_path=$page_base_path-object${object_idx}
      #object_png_path=$object_base_path.png
      #object_bbox=${object_bbox_list[object_idx]}
      object_jp2_pdf_path=${object_jp2_pdf_path_list[object_idx]}
      # TODO set object position
      # convert object.png -gravity center -background white -extent "%[papersize:A4]" x.pdf
      pdftk_args+=(stamp $object_jp2_pdf_path)
    done
    page_output_pdf_path=$tempdir/page-$page_number_pad.output.pdf
    # take the "novectors" pdf and add the vectors as raster images
    pdftk $page_novectors_pdf_path "${pdftk_args[@]}" output $page_output_pdf_path
    page_output_pdf_path_list+=($page_output_pdf_path)
    #fi
    fi

    # this works to combine multiple pdf page layers to one pdf page
    # but we use pdflatex to directly convert multiple images to one pdf page
    if false; then
    page_output_pdf_path=$tempdir/page-$page_number_pad.output.pdf
    page_output_pdf_tmp_path=$tempdir/page-$page_number_pad.output.tmp.pdf
    cp $page_novectors_pdf_path $page_output_pdf_path
    for object_idx in ${!object_bbox_list[@]}; do
      object_jp2_pdf_path=${object_jp2_pdf_path_list[object_idx]}
      mv $page_output_pdf_path $page_output_pdf_tmp_path
      echo "output $page_output_pdf_path - adding $object_jp2_pdf_path"
      # wrong
      #pdftk $page_output_pdf_tmp_path stamp $object_jp2_pdf_path output $page_output_pdf_path
      pdftk $object_jp2_pdf_path stamp $page_output_pdf_tmp_path output $page_output_pdf_path
      rm $page_output_pdf_tmp_path
    done
    fi

    # use pdflatex directly to convert images to pdf
    #page_output_vectors_tex_path=$tempdir/page-$page_number_pad.output.vectors.tex
    #page_output_vectors_pdf_path=$tempdir/page-$page_number_pad.output.vectors.pdf
    page_output_vectors_tex_path=$tempdir/page-$page_number_pad.output.tex
    page_output_vectors_pdf_path=$tempdir/page-$page_number_pad.output.pdf

    cat >$page_output_vectors_tex_path <(

      echo "\documentclass{article}"
      echo
      echo "\usepackage{graphicx}"
      echo "\usepackage{tikz}"
      echo
      echo "\setlength{\paperwidth}{${page_pdf_width_pt}bp}"
      echo "\setlength{\paperheight}{${page_pdf_height_pt}bp}"
      echo
      echo "\begin{document}"
      echo
      echo "\pagestyle{empty}"
      echo
      echo "\begin{tikzpicture}[remember picture,overlay]"
      echo

      # loop objects
      for object_idx in ${!object_bbox_list[@]}; do

        #object_jp2_pdf_path=${object_jp2_pdf_path_list[object_idx]}
        object_jp2_path=${object_jp2_path_list[object_idx]}
        object_bbox=${object_bbox_list[object_idx]}
        echo "% object bbox: $object_bbox"
        read object_bbox_x object_bbox_y object_bbox_l object_bbox_t < <(echo "$object_bbox" | tr '[x+]' ' ')
        # TODO why is 10px == 1bp
        # maybe because 720dpi / 72dpi == 10
        # TODO try with 600dpi
        object_bbox_x_bp=$(echo "scale=10; $object_bbox_x / 10" | bc | sed -E 's/(.)\.?0+$/\1/')
        object_bbox_y_bp=$(echo "scale=10; $object_bbox_y / 10" | bc | sed -E 's/(.)\.?0+$/\1/')
        object_bbox_l_bp=$(echo "scale=10; $object_bbox_l / 10" | bc | sed -E 's/(.)\.?0+$/\1/')
        object_bbox_t_bp=$(echo "scale=10; $object_bbox_t / 10" | bc | sed -E 's/(.)\.?0+$/\1/')

        # l and t -> "pt" unit in latex
        echo "\node[anchor=north west,inner sep=0pt,xshift=${object_bbox_l_bp}bp,yshift=-${object_bbox_t_bp}bp] at (current page.north west){"
        #echo "\node[anchor=north west,inner sep=0pt,xshift=${object_bbox_l_bp}pt,yshift=-${object_bbox_t_bp}pt] at (current page.north west){"

        # x and y -> "bp" unit in latex
        echo "  \includegraphics[width=${object_bbox_x_bp}bp,height=${object_bbox_y_bp}bp]{$(basename "$object_jp2_path")}"
        #echo "  \includegraphics[width=${object_bbox_x_bp}pt,height=${object_bbox_y_bp}pt]{$(basename "$object_jp2_path")}"

        # no? this is only true for a small part of an edge case.
        # ... this gives the best result (sharp images) in chromium PDF reader
        # and all other variants produce blurry images

        # FIXME something else is broken...
        # the object_bbox has a small error

        # width and height look okay, so probably "bp" is better than "pt"
        # so lets use "pt" also for l and t = left and top offsets

        echo "};"
        echo
      done

      # add text and images from original pdf
      # https://tex.stackexchange.com/questions/15314/how-can-i-superimpose-latex-tex-output-over-a-pdf-file

      # TODO? \node[anchor=north west,inner sep=0pt]
      echo "\node[inner sep=0pt] at (current page.center) {"
      echo "  \includegraphics[page=1]{$(basename $page_novectors_pdf_path)}"
      echo "};"
      echo

      # TODO add custom text
      #echo "\node at (2cm,2cm) {hello world};"

      echo "\end{tikzpicture}"
      echo

      echo "\end{document}"
    )

    # pdflatex creates files in workdir
    pushd "$tempdir"

    # we must run latex twice...
    for i in 1 2; do
      max_print_line=9999 \
      pdflatex $page_output_vectors_tex_path
      # TODO
      # >/dev/null
    done
    popd

    #pdflatex --max-print-line=9999 $page_output_vectors_tex_path

    # no. done by pdflatex
    if false; then
    # TODO? use pdflatex to embed the original text and images = novectors pdf
    page_output_pdf_path=$tempdir/page-$page_number_pad.output.pdf
    pdftk $page_output_vectors_pdf_path stamp $page_novectors_pdf_path output $page_output_pdf_path
    page_output_pdf_path_list+=($page_output_pdf_path)
    else
    page_output_pdf_path_list+=($page_output_vectors_pdf_path)
    fi

  done # loop resolutions



  # TODO quality control: compare input and output
  # render the output pdf page to a png image
  # and get the difference between input png and output png

  if ! $keep_temp_files; then
    rm $page_pdf_path
    rm $page_vectors_pdf_path
    rm $page_novectors_pdf_path
    rm $page_png_path
  fi

  # continue with next page

done # loop pages



# combine PDF pages
#pdftk ${jp2_pdf_path_list[@]} cat output combined.jp2.pdf
# filter by quality
# no, we dont use $jp2_quality_min etc any more
if false; then
for jp2_quality in $(seq $jp2_quality_min $jp2_quality_inc $jp2_quality_max); do
  pdf_path_list=()
  for pdf_path in ${jp2_pdf_path_list[@]}; do
    # test if pdf_path ends with ".q$jp2_quality.jp2.pdf"
    if echo "$pdf_path" | grep -q "\.q$jp2_quality\.jp2\.pdf$"; then
      pdf_path_list+=($pdf_path)
    fi
  done
  pdftk "${pdf_path_list[@]}" cat output combined.q$jp2_quality.jp2.pdf
done
#pdftk ${jpg_pdf_path_list[@]} cat output combined.jpg.pdf
fi

if [[ "${#page_output_pdf_path_list}" == "0" ]]; then
  echo "error: page_output_pdf_path_list is empty"
  exit 1
fi

echo "writing output pdf: $combined_output_pdf_path"
pdftk "${page_output_pdf_path_list[@]}" cat output "$combined_output_pdf_path"

echo "done. keeping tempdir $tempdir"

exit



#pdftoppm input.pdf outputname -png -rx 300 -ry 300

#pdftoppm input.pdf outputname -png -r 300

#page=123
#pdftoppm input.pdf outputname -png -f $page_number -singlefile
#pdftoppm input.pdf outputname -png -f $page_number -singlefile -r 600
