Ada Bitcoin Script Interpreter
==============================

This a bitcoin script interpreter written in the highly reliable language Ada.

Features:

- Evaluate all Bitcoin Script opcodes
- Base58 and Base64 Encoding
- Focused OpenSSL binding for secp256k1 and ripemd160

Incomplete:

- Arithmetic Opcodes
- Crypto Opcodes
- Locktime Opcodes
- Pseudo-words Opcodes

Differences to the standard:

- Nested If/Else blocks are supported
- OP_VERIF and OP_VERNOTIF will only invalidate if they are evaluated
- Segwit is not, and never will be, supported.

## Dependencies

- OpenSSL

Windows: I've included the latest 1.1.0 openSSL binaries since they are a little difficult to find. The gpr file assumes the dlls will be in the binaries/system/word_size folder.

Linux: Use your package manager to install the openssl dev libraries. 

For ubuntu based systems: 

    sudo apt-get install libssl-dev

## Compiling

To compile the .dll/.so library use the bitcoin_script.gpr project file.

This project comes with 3 Scenario Options:

  | Option    | Values           |
  | --------- | ---------------- |
  | Word_Size | 32 or 64         | 
  | System    | windows or posix |
  | Debug     | Yes or No        |

To compile from command line with all the defaults (64, windows, No):

    gprbuild -P bitcoin_script.gpr

To compile from command line with specific options:

    gprbuild -P bitcoin_script.gpr -XWord_Size=32 -XSystem=posix -XDebug=Yes

Or the free IDE [Gnat Programming Studio](http://libre.adacore.com/download/) can open and compile gpr files

## Testing

This project uses the AUnit framework and has a large number of unit tests. When developing, it's generally better to use the test project to compile. This project extends the basic project with extra unit testing code.

To compile from command line with all the defaults (64, windows, No):

    gprbuild -P bitcoin_script-tests.gpr

To compile from command line with specific options:

    gprbuild -P bitcoin_script-tests.gpr -XWord_Size=32 -XSystem=posix -XDebug=Yes

Or the free IDE [Gnat Programming Studio](http://libre.adacore.com/download/) can open and compile gpr files. Simply hit the play button to build the library and run the tests.

## Contributing

This project will use [GitFlow](https://datasift.github.io/gitflow/IntroducingGitFlow.html).

To contribute, create a feature branch off develop. For example: `feature/ripemd160-support`

When your feature is complete, and the tests run, simply submit a pull request back to `develop`.  I'll review the changes.
