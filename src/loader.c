#include <inttypes.h>
#include "loader.h"
#include "fat32.h"
#include "mm.h"
#include "sched.h"
#include "utils.h"
#include "debug.h"

// va should be page-aligned.
int load_file_to_memory(struct task_struct *tsk, const char *name, unsigned long va) {
  struct fat32_fs hfat;
  if (fat32_get_handle(&hfat) < 0) {
    WARN("failed to find fat32 filesystem.");
    return -1;
  }

  struct fat32_file file;
  //fat32_filename_dump(&hfat);
  if (fat32_lookup(&hfat, name, &file) < 0) {
    WARN("requested file \"%s\" is not found.", name);
    return -1;
  }

  int remain = fat32_file_size(&file);
  int offset = 0;
  unsigned long current_va = va & PAGE_MASK;

  while (remain > 0) {
    uint8_t *buf = allocate_task_page(tsk, current_va);
    int readsz = MIN(PAGE_SIZE, remain);
    int actual = fat32_read(&file, buf, offset, readsz);

    if (readsz != actual) {
      WARN("error during file read");
      return -1;
    }

    remain -= readsz;
    offset += readsz;
    current_va += PAGE_SIZE;
  }

  tsk->name = name;

  return 0;
}


int raw_binary_loader (void *arg, unsigned long *pc,
    unsigned long *sp) {
  struct raw_binary_loader_args *loader_args = arg;
  if (load_file_to_memory(current,
        loader_args->filename, loader_args->load_addr) < 0)
    return -1;

  *pc = loader_args->entry_point;
  *sp = loader_args->sp;

  return 0;
}
