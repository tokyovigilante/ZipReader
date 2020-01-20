#include <errno.h>
#include <string.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdint.h>

#include <minizip/mz.h>
#include <minizip/mz_strm.h>
#include <minizip/mz_zip.h>
#include <minizip/mz_zip_rw.h>

int32_t list_zip_archive (void *reader) {

    mz_zip_file *file_info = NULL;
    uint32_t ratio = 0;
    int16_t level = 0;
    int32_t err = MZ_OK;
    struct tm tmu_date;
    const char *string_method = NULL;
    char crypt = ' ';

    err = mz_zip_reader_goto_first_entry(reader);

       if (err != MZ_OK && err != MZ_END_OF_LIST)
       {
           printf("Error %"PRId32" going to first entry in archive\n", err);
           mz_zip_reader_delete(&reader);
           return err;
       }

       printf("      Packed     Unpacked Ratio Method   Attribs Date     Time  CRC-32     Name\n");
       printf("      ------     -------- ----- ------   ------- ----     ----  ------     ----\n");

       /* Enumerate all entries in the archive */
       do
       {
           err = mz_zip_reader_entry_get_info(reader, &file_info);

           if (err != MZ_OK)
           {
               printf("Error %"PRId32" getting entry info in archive\n", err);
               break;
           }

           ratio = 0;
           if (file_info->uncompressed_size > 0)
               ratio = (uint32_t)((file_info->compressed_size * 100) / file_info->uncompressed_size);

           /* Display a '*' if the file is encrypted */
           if (file_info->flag & MZ_ZIP_FLAG_ENCRYPTED)
               crypt = '*';
           else
               crypt = ' ';

           switch (file_info->compression_method)
           {
           case MZ_COMPRESS_METHOD_STORE:
               string_method = "Stored";
               break;
           case MZ_COMPRESS_METHOD_DEFLATE:
               level = (int16_t)((file_info->flag & 0x6) / 2);
               if (level == 0)
                   string_method = "Defl:N";
               else if (level == 1)
                   string_method = "Defl:X";
               else if ((level == 2) || (level == 3))
                   string_method = "Defl:F"; /* 2: fast , 3: extra fast */
               else
                   string_method = "Defl:?";
               break;
           case MZ_COMPRESS_METHOD_BZIP2:
               string_method = "BZip2";
               break;
           case MZ_COMPRESS_METHOD_LZMA:
               string_method = "LZMA";
               break;
           default:
               string_method = "?";
           }

           mz_zip_time_t_to_tm(file_info->modified_date, &tmu_date);

           /* Print entry information */
           printf("%12"PRId64" %12"PRId64"  %3"PRIu32"%% %6s%c %8"PRIx32" %2.2"PRIu32\
                  "-%2.2"PRIu32"-%2.2"PRIu32" %2.2"PRIu32":%2.2"PRIu32" %8.8"PRIx32"   %s\n",
                   file_info->compressed_size, file_info->uncompressed_size, ratio,
                   string_method, crypt, file_info->external_fa,
                   (uint32_t)tmu_date.tm_mon + 1, (uint32_t)tmu_date.tm_mday,
                   (uint32_t)tmu_date.tm_year % 100,
                   (uint32_t)tmu_date.tm_hour, (uint32_t)tmu_date.tm_min,
                   file_info->crc, file_info->filename);

           err = mz_zip_reader_goto_next_entry(reader);

           if (err != MZ_OK && err != MZ_END_OF_LIST)
           {
               printf("Error %"PRId32" going to next entry in archive\n", err);
               break;
           }
       }
       while (err == MZ_OK);

       if (err == MZ_END_OF_LIST)
           return MZ_OK;

       return err;
}
