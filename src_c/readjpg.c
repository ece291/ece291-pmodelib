#include <stdio.h>
#include <stdlib.h>

#include "jpeglib.h"

static struct jpeg_decompress_struct cinfo;
static struct jpeg_error_mgr jerr;

int readjpg_init(FILE *infile, unsigned long *pWidth, unsigned long *pHeight)
{
    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_decompress(&cinfo);

    jpeg_stdio_src(&cinfo, infile);

    jpeg_read_header(&cinfo, TRUE);

    jpeg_start_decompress(&cinfo);

    *pWidth = cinfo.output_width;
    *pHeight = cinfo.output_height;

    return 0;
}

void readjpg_get_row(unsigned char *pRow)
{
    int i;

    jpeg_read_scanlines(&cinfo, &pRow, 1);
    for(i=cinfo.output_width; i>0; i--) {
	*(pRow+4*i+0) = *(pRow+3*i+2);
	*(pRow+4*i+1) = *(pRow+3*i+1);
	*(pRow+4*i+2) = *(pRow+3*i+0);
    }
}


void readjpg_cleanup(void)
{
    jpeg_finish_decompress(&cinfo);
    jpeg_destroy_decompress(&cinfo);
}
