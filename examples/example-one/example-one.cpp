#include "loadimage.hh"
#include "sleigh.hh"
#include "emulate.hh"
#include "memstate.hh"
#include "hutch.hpp"
#include <iostream>
#include <filesystem>

// x86 insns
//
// push ebp            \x55
// move ebp, esp       \x89\xe5
// mov eax, 0x12345678 \xb8\x78\x56\x34\x12
//
// static uint1 code[] = { 0x55, 0x89, 0xe5, 0xb8, 0x78, 0x56, 0x34, 0x12 };


// int main(int argc, char *argv[])
// {
//     size_t fsize;
//     uint1* fbytes = nullptr;

//     if (argc == 2) {
//         fsize = filesystem::file_size (argv[1]);
//         fbytes = new uint1[fsize];
//         ifstream file (argv[1], ios::in | ios::binary);
//         file.read ((char*)fbytes, fsize);
//     }

//     hutch hutch_h;
//     hutch_insn insn;

//     hutch_h.preconfigure ("../../processors/x86/languages/x86.sla", IA32);
//     hutch_h.options (OPT_IN_DISP_ADDR | OPT_IN_PCODE | OPT_IN_ASM);

//     auto img = (argc == 2) ? fbytes : code;
//     auto imgsize = (argc == 2) ? fsize : sizeof (code);

//     hutch_h.initialize (img, imgsize, 0x12345680);

//     hutch_h.disasm (UNIT_BYTE, 0, imgsize);

//     cout << "\n* Now insn by insn convert to raw pcode\n";

//     // Convert insn by insn to pcode and print.
//     for (auto [buf, pcode] = pair{ code, (optional<vector<PcodeData>>)0 };
//          pcode = insn.expand_insn_to_rpcode (&hutch_h, buf, sizeof (code));
//          buf = nullptr) {
//         for (auto i = 0; i < pcode->size (); ++i) {
//             hutch_print_pcodedata (cout, pcode->at (i));
//         }
//     }

//     return 0;
// }


#include <iostream>
#include <string>

#include "hutch.hpp"

// x86 insns
//
// push ebp            \x55
// move ebp, esp       \x89\xe5
// mov eax, 0x12345678 \xb8\x78\x56\x34\x12
//
static uint1 code[] = { 0x55, 0x89, 0xe5, 0xb8, 0x78, 0x56, 0x34, 0x12 };

int main(int argc, char *argv[])
{
    size_t fsize;
    uint1* fbytes = nullptr;

    if (argc == 2) {
        fsize = filesystem::file_size (argv[1]);
        fbytes = new uint1[fsize];
        ifstream file (argv[1], ios::in | ios::binary);
        file.read ((char*)fbytes, fsize);
    }

    hutch hutch_h;
    hutch_insn insn;

    hutch_h.preconfigure("../../processors/x86/languages/x86.sla", IA32);

    // Can display Address info, pcode, assembly alone or in combination with
    // each other. Omission of hutch_h.options() will display a default of asm +
    // address info.
    hutch_h.options (OPT_IN_DISP_ADDR | OPT_IN_PCODE | OPT_IN_ASM);

    auto img = (argc == 2) ? fbytes : code;
    auto imgsize = (argc == 2) ? fsize : sizeof (code);

    // Need to translate the buffer into internal representation prior to use.
    // Loaded image is persistent.
    hutch_h.initialize(img, imgsize, 0x12345680);

    // Able to disassemble at specific offset + length.
    // The offset + length can be specified in terms bytes or instructions.
    hutch_h.disasm(UNIT_BYTE, 0, imgsize);

    // The above is useful for handling a single persistent image. If you have
    // snippets you want to pass and convert to pcode you only need to run the
    // hutch_h.preconfigure step before continuing to the below.
    cout << "\n* Convert insn by insn to raw pcode\n";

    // Convert insn by insn to pcode and print.
    for (auto [buf, pcode] = pair{ img, (optional<vector<PcodeData>>)0 };
         pcode = insn.expand_insn_to_rpcode (&hutch_h, buf, imgsize);
         buf = nullptr)
    {
        cout << "** converting insn..." << endl;
        for (auto i = 0; i < pcode->size (); ++i) {
            hutch_print_pcodedata (cout, pcode->at (i));
        }
    }


    return 0;
}
