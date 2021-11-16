use Config;
if ($Config{usethreads}) {
    print "has thread support\n"
} 

use Config qw(myconfig config_sh config_vars config_re);

print myconfig();

print config_sh();

print config_re();

config_vars(qw(osname archname));

