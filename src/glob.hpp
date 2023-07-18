// A simple helper function to return all filenames matching a wildcard pattern
// as a vector
//
#include <iostream>
#include <glob.h>
#include <vector>

std::vector <std::string> Glob(std::string pattern) {

    glob_t my_glob;

    int cc = glob(pattern.c_str(),
                  GLOB_TILDE_CHECK, // flags
                  NULL,
                  &my_glob);

    std::vector <std::string> vglob;

    if (cc == 0) {
        for (int i = 0; i < (int)my_glob.gl_pathc; i++) {
            vglob.push_back(std::string(my_glob.gl_pathv[i]));
        }
        globfree(&my_glob);
    }

    return vglob;
}
