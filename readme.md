# pdf-compress-vector-graphics

compress large vector graphics in the "content streams" of PDF files by replacing them with high-quality JP2 raster images

## why

as far as i know, currently, no PDF compressor can do this

other PDF compressors can compress only raster images, but fail to compress large vector graphics

## large vector graphics

the large vector graphics usually come from tools like "Adobe InDesign"

this is a known issue, see also

- https://community.adobe.com/t5/acrobat-discussions/pdf-size-is-content-stream-the-problem/m-p/2286382
- https://community.adobe.com/t5/acrobat-sdk-discussions/how-to-remove-content-streams/m-p/8347022
- https://support.neuxpower.com/hc/en-us/articles/360022343714
   - Unlike images which can be resized or recompressed with a more optimal quality to reduce them in size, content streams tend to be large and cannot be directly compressed. However, there are workarounds to compress the size of PDF files made from content streams. The main one is to try and reprint the PDF using a browser PDF printer and then use a PDF compressor to reduce the size of the resulting file.

## high-quality JP2 raster images

high-quality is 600dpi, to produce good quality when printing

JP2 raster images, because JP2 offers better compression than JPG.
on the downside, JP2 requires more memory, but most PDF viewers should have enough memory.
WEBP raster images are not supported in PDF files

## analyze pdf size

### offline tools

use ghostscript to split the PDF into text, raster images, vector graphics:

https://stackoverflow.com/questions/29657335/how-can-i-remove-all-images-from-a-pdf

```
gs -q -o onlyvectors.pdf -sDEVICE=pdfwrite -dFILTERIMAGE -dFILTERTEXT input.pdf
gs -q -o onlytext.pdf -sDEVICE=pdfwrite -dFILTERIMAGE -dFILTERVECTOR input.pdf
gs -q -o onlyimages.pdf -sDEVICE=pdfwrite -dFILTERVECTOR -dFILTERTEXT input.pdf
```

now compare the file sizes:

```
du -b input.pdf onlyvectors.pdf onlytext.pdf onlyimages.pdf | sort -n -r
```

example output:

```
74258862        input.pdf
52904938        onlyvectors.pdf
743759          onlyimages.pdf
677472          onlytext.pdf
```

here, onlyvectors.pdf is 70% of input.pdf

### online tools

- https://wecompress.com/en/analyze - online PDF file analyzer
   - via https://neuxpower.com/blog/why-is-pdf-file-so-big-and-how-to-reduce-pdf-file-size
