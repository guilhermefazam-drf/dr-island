# Loads the helper library inside Apple's perl so MediaRemote answers. Usage: perl nowplaying.pl /path/libnowplaying.dylib
use DynaLoader;
my $lib = DynaLoader::dl_load_file($ARGV[0], 0) or exit 1;
my $sym = DynaLoader::dl_find_symbol($lib, "run") or exit 1;
my $run = DynaLoader::dl_install_xsub("main::run", $sym);
&$run("main::run");
