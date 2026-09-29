#include <dlfcn.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>

int main(int argc, char** argv) {
    if (argc != 5) {
        std::fprintf(stderr, "usage: driver ibex|cva6 LIB DIRECTORY MAX_CYCLES\n");
        return 2;
    }
    void* handle = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    if (!handle) {
        std::fprintf(stderr, "dlopen: %s\n", dlerror());
        return 1;
    }
    int status = -1, failure = -1, execution = -1;
    int rc = -1;
    if (std::strcmp(argv[1], "ibex") == 0) {
        using Entry = int (*)(const char*, int, int*, int*, int*);
        auto entry = reinterpret_cast<Entry>(dlsym(handle, "contract_ibex_test_attacker_file_v1"));
        if (entry) rc = entry(argv[3], std::atoi(argv[4]), &status, &failure, &execution);
    } else if (std::strcmp(argv[1], "cva6") == 0) {
        using Entry = int (*)(const char*, int, int*);
        auto entry = reinterpret_cast<Entry>(dlsym(handle, "contract_cva6_test_attacker_file_v1"));
        if (entry) rc = entry(argv[3], std::atoi(argv[4]), &status);
    }
    if (rc != 0) {
        std::fprintf(stderr, "native file entry failed or is missing\n");
        dlclose(handle);
        return 1;
    }
    std::printf("%d,%d,%d\n", status, failure, execution);
    dlclose(handle);
    return 0;
}
