# Ruby interpreter segfault related to EventMachine

On Ubuntu 18.04 and Ruby 2.5.1 the EventMachine gem may cause Ruby to segfault if the process executes foreign code in other dynamic libraries linked to libc++.

This repository attempts to provide a minimal reproduction scenario for this issue. It contains two C++ shared libraries with C interfaces: `libembuga` and `libembugb` and a number of tests, some of which cause Ruby to segfault.

## libembuga.so

`libembuga.so` is built with Clang linked to libc++: the new standard C++ library built for Clang. It exposes one public function: `int embuga_demo(int x)`. The function returns `42 + x` if x is bigger than 0 or -1 otherwise. It is exposed to Ruby code as `EmbugA.embuga_demo` defined in `embuga_ffi.rb`.

Internally, `embuga_demo` wraps a C++ class that throws an `std::runtime_exception` if the passed number is lesser than zero. The function abstract this behavior away by printing "Error!" to STDERR and returning -1.

## libembugb.so

`libembugb.so` is built with Clang but, in contrast with `libembuga`, linked to `libstdc++`: the “old” standard C++ library used by GCC. It exposes one public function: `int embugb_demo(int x)` that acts identically to embuga_demo from `libembuga.so`. It is exposed to Ruby code as `EmbugB.embuga_demo` defined in `embugb_ffi.rb`.

## Testing approach

I’m trying to confirm a theory that requiring the EventMachine gem affects the behavior of C++ exceptions in loaded dynamic libraries that use libc++. Each test runs the function exposed by each tested library once with a positive number (5) and once with a negative number (-1). Tests that include EventMachine add nothing else but requiring the eventmachine gem in a certain order.

### Test 1. libembuga standalone (test_a.rb)

```
# bundle exec test_a.rb
47
Error!
-1
```

Expected.

### Test 2. libembugb standalone (test_b.rb)


```
# bundle exec test_b.rb
47
Error!
-1
```

Expected.

### Test 3. loading libembuga, then libembugb (test_a_b.rb)

```
# bundle exec test_a_b.rb
47
Error!
-1
47
Error!
-1
```

Expected.

### Test 4. loading libembugb, then libembuga (test_b_a.rb)

```
47
Error!
-1
47
Error!
-1
```

Expected.

### Test 5. loading eventmachine (test_em.rb)

```
# bundle exec test_em.rb
```

Expected.

### Test 6. loading eventmachine, then libembuga (test_em_a.rb)

```
# bundle exec test_em_a.rb
47
Error!
-1
```

Expected.

### Test 7. loading libembuga, then eventmachine (test_a_em.rb)

```
# bundle exec test_a_em.rb
root@93b0624bf022:/checkout/embug-1203# bundle exec test_a_em.rb
47
terminate called after throwing an instance of 'std::runtime_error'
test_a_em.rb:7: [BUG] Segmentation fault at 0x0000000000000000
ruby 2.5.1p57 (2018-03-29 revision 63029) [x86_64-linux-gnu]

-- Control frame information -----------------------------------------------
c:0016 p:---- s:0097 e:000096 CFUNC  :embuga_demo
c:0015 p:0047 s:0092 e:000090 TOP    test_a_em.rb:7 [FINISH]
c:0014 p:---- s:0088 e:000087 CFUNC  :load
c:0013 p:0148 s:0083 e:000082 METHOD /usr/lib/ruby/vendor_ruby/bundler/cli/exec.rb:75
c:0012 p:0075 s:0073 e:000072 METHOD /usr/lib/ruby/vendor_ruby/bundler/cli/exec.rb:28
c:0011 p:0026 s:0068 e:000067 METHOD /usr/lib/ruby/vendor_ruby/bundler/cli.rb:424
c:0010 p:0064 s:0063 e:000062 METHOD /usr/lib/ruby/vendor_ruby/thor/command.rb:27
c:0009 p:0047 s:0055 e:000054 METHOD /usr/lib/ruby/vendor_ruby/thor/invocation.rb:126
c:0008 p:0259 s:0048 e:000047 METHOD /usr/lib/ruby/vendor_ruby/thor.rb:369
c:0007 p:0010 s:0035 e:000034 METHOD /usr/lib/ruby/vendor_ruby/bundler/cli.rb:27
c:0006 p:0062 s:0030 e:000029 METHOD /usr/lib/ruby/vendor_ruby/thor/base.rb:444
c:0005 p:0010 s:0023 e:000022 METHOD /usr/lib/ruby/vendor_ruby/bundler/cli.rb:18
c:0004 p:0079 s:0017 e:000016 BLOCK  /usr/bin/bundle:30
c:0003 p:0002 s:0011 e:000010 METHOD /usr/lib/ruby/vendor_ruby/bundler/friendly_errors.rb:122
c:0002 p:0046 s:0006 E:000400 EVAL   /usr/bin/bundle:22 [FINISH]
c:0001 p:0000 s:0003 E:001fd0 (none) [FINISH]

-- Ruby level backtrace information ----------------------------------------
/usr/bin/bundle:22:in `<main>'
/usr/lib/ruby/vendor_ruby/bundler/friendly_errors.rb:122:in `with_friendly_errors'
/usr/bin/bundle:30:in `block in <main>'
/usr/lib/ruby/vendor_ruby/bundler/cli.rb:18:in `start'
/usr/lib/ruby/vendor_ruby/thor/base.rb:444:in `start'
/usr/lib/ruby/vendor_ruby/bundler/cli.rb:27:in `dispatch'
/usr/lib/ruby/vendor_ruby/thor.rb:369:in `dispatch'
/usr/lib/ruby/vendor_ruby/thor/invocation.rb:126:in `invoke_command'
/usr/lib/ruby/vendor_ruby/thor/command.rb:27:in `run'
/usr/lib/ruby/vendor_ruby/bundler/cli.rb:424:in `exec'
/usr/lib/ruby/vendor_ruby/bundler/cli/exec.rb:28:in `run'
/usr/lib/ruby/vendor_ruby/bundler/cli/exec.rb:75:in `kernel_load'
/usr/lib/ruby/vendor_ruby/bundler/cli/exec.rb:75:in `load'
test_a_em.rb:7:in `<top (required)>'
test_a_em.rb:7:in `embuga_demo'

-- Machine register context ------------------------------------------------
 RIP: 0x00007fd0f5fab873 RBP: 0x00007fd0f9710840 RSP: 0x00007ffcc1616890
 RAX: 0x00007fd0f629ab08 RBX: 0x00007fd0f6913350 RCX: 0x000055e9e89d7900
 RDX: 0x00007fd0f5fc7000 RDI: 0x00007fd0f629ab08 RSI: 0x000055e9e89d7900
  R8: 0x00000000ffffffff  R9: 0x00007ffcc1616290 R10: 0x00007fd0f68ea1b0
 R11: 0x00007fd0f5fab8c4 R12: 0x000055e9e8a0aa60 R13: 0x00007ffcc1616b00
 R14: 0x00007ffcc1616ae0 R15: 0x00007ffcc1616b30 EFL: 0x0000000000010246

-- C level backtrace information -------------------------------------------
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(0x7fd0f98d2685) [0x7fd0f98d2685]
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(0x7fd0f98d28bc) [0x7fd0f98d28bc]
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(0x7fd0f979c884) [0x7fd0f979c884]
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(0x7fd0f98626c2) [0x7fd0f98626c2]
/lib/x86_64-linux-gnu/libc.so.6(0x7fd0f9362f20) [0x7fd0f9362f20]
/usr/lib/x86_64-linux-gnu/libstdc++.so.6(0x7fd0f5fab873) [0x7fd0f5fab873]
/usr/lib/x86_64-linux-gnu/libstdc++.so.6(0x7fd0f5fb1a06) [0x7fd0f5fb1a06]
/usr/lib/x86_64-linux-gnu/libstdc++.so.6(0x92a41) [0x7fd0f5fb1a41]
/usr/lib/x86_64-linux-gnu/libstdc++.so.6(0x92c74) [0x7fd0f5fb1c74]
/checkout/embug-1203/libembuga/libembuga.so(_ZN6EmbugA4demoEi+0x65) [0x7fd0f6ddf325]
/checkout/embug-1203/libembuga/libembuga.so(embuga_demo+0x2c) [0x7fd0f6ddf1fc]
/var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi_c.so(ffi_call_unix64+0x55) [0x7fd0f6ffb81d]
/var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi_c.so(0x19159) [0x7fd0f6ffb159]
/var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi_c.so(ffi_call+0x66) [0x7fd0f6ffb1d6]
/var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi_c.so(rbffi_CallFunction+0xe7) [0x7fd0f6fefbe7]
/var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi_c.so(0x11424) [0x7fd0f6ff3424]
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(0x7fd0f98bafa9) [0x7fd0f98bafa9]
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(0x7fd0f98c94d3) [0x7fd0f98c94d3]
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(0x7fd0f98c0370) [0x7fd0f98c0370]
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(0x7fd0f98c5744) [0x7fd0f98c5744]
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(0x7fd0f97dbb11) [0x7fd0f97dbb11]
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(0x7fd0f97dc0b8) [0x7fd0f97dc0b8]
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(0x7fd0f97dc1d0) [0x7fd0f97dc1d0]
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(0x7fd0f98bafa9) [0x7fd0f98bafa9]
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(0x7fd0f98c94d3) [0x7fd0f98c94d3]
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(0x7fd0f98c0370) [0x7fd0f98c0370]
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(0x7fd0f98c5744) [0x7fd0f98c5744]
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(0x7fd0f97a00c4) [0x7fd0f97a00c4]
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(ruby_exec_node+0x1d) [0x7fd0f97a1f4d]
/usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5(ruby_run_node+0x1e) [0x7fd0f97a442e]
test_a_em.rb(0x55e9e79a28cb) [0x55e9e79a28cb]
/lib/x86_64-linux-gnu/libc.so.6(__libc_start_main+0xe7) [0x7fd0f9345b97] ../csu/libc-start.c:310
test_a_em.rb(_start+0x2a) [0x55e9e79a28fa]

-- Other runtime information -----------------------------------------------

* Loaded script: test_a_em.rb

* Loaded features:

    0 enumerator.so
    1 thread.rb
    2 rational.so
    3 complex.so
    4 /usr/lib/x86_64-linux-gnu/ruby/2.5.0/enc/encdb.so
    5 /usr/lib/x86_64-linux-gnu/ruby/2.5.0/enc/trans/transdb.so
    6 /usr/lib/x86_64-linux-gnu/ruby/2.5.0/rbconfig.rb
    7 /usr/lib/ruby/2.5.0/rubygems/compatibility.rb
    8 /usr/lib/ruby/2.5.0/rubygems/defaults.rb
    9 /usr/lib/ruby/2.5.0/rubygems/deprecate.rb
   10 /usr/lib/ruby/2.5.0/rubygems/errors.rb
   11 /usr/lib/ruby/2.5.0/rubygems/version.rb
   12 /usr/lib/ruby/2.5.0/rubygems/requirement.rb
   13 /usr/lib/ruby/2.5.0/rubygems/platform.rb
   14 /usr/lib/ruby/2.5.0/rubygems/basic_specification.rb
   15 /usr/lib/ruby/2.5.0/rubygems/stub_specification.rb
   16 /usr/lib/ruby/2.5.0/rubygems/util/list.rb
   17 /usr/lib/x86_64-linux-gnu/ruby/2.5.0/stringio.so
   18 /usr/lib/ruby/2.5.0/uri/rfc2396_parser.rb
   19 /usr/lib/ruby/2.5.0/uri/rfc3986_parser.rb
   20 /usr/lib/ruby/2.5.0/uri/common.rb
   21 /usr/lib/ruby/2.5.0/uri/generic.rb
   22 /usr/lib/ruby/2.5.0/uri/ftp.rb
   23 /usr/lib/ruby/2.5.0/uri/http.rb
   24 /usr/lib/ruby/2.5.0/uri/https.rb
   25 /usr/lib/ruby/2.5.0/uri/ldap.rb
   26 /usr/lib/ruby/2.5.0/uri/ldaps.rb
   27 /usr/lib/ruby/2.5.0/uri/mailto.rb
   28 /usr/lib/ruby/2.5.0/uri.rb
   29 /usr/lib/ruby/2.5.0/rubygems/specification.rb
   30 /usr/lib/ruby/2.5.0/rubygems/exceptions.rb
   31 /usr/lib/ruby/vendor_ruby/rubygems/defaults/operating_system.rb
   32 /usr/lib/ruby/2.5.0/rubygems/dependency.rb
   33 /usr/lib/ruby/2.5.0/rubygems/core_ext/kernel_gem.rb
   34 /usr/lib/ruby/2.5.0/monitor.rb
   35 /usr/lib/ruby/2.5.0/rubygems/core_ext/kernel_require.rb
   36 /usr/lib/ruby/2.5.0/rubygems.rb
   37 /usr/lib/ruby/2.5.0/rubygems/path_support.rb
   38 /usr/lib/ruby/vendor_ruby/did_you_mean/version.rb
   39 /usr/lib/ruby/vendor_ruby/did_you_mean/core_ext/name_error.rb
   40 /usr/lib/ruby/vendor_ruby/did_you_mean/levenshtein.rb
   41 /usr/lib/ruby/vendor_ruby/did_you_mean/jaro_winkler.rb
   42 /usr/lib/ruby/vendor_ruby/did_you_mean/spell_checker.rb
   43 /usr/lib/ruby/2.5.0/delegate.rb
   44 /usr/lib/ruby/vendor_ruby/did_you_mean/spell_checkers/name_error_checkers/class_name_checker.rb
   45 /usr/lib/ruby/vendor_ruby/did_you_mean/spell_checkers/name_error_checkers/variable_name_checker.rb
   46 /usr/lib/ruby/vendor_ruby/did_you_mean/spell_checkers/name_error_checkers.rb
   47 /usr/lib/ruby/vendor_ruby/did_you_mean/spell_checkers/method_name_checker.rb
   48 /usr/lib/ruby/vendor_ruby/did_you_mean/spell_checkers/key_error_checker.rb
   49 /usr/lib/ruby/vendor_ruby/did_you_mean/spell_checkers/null_checker.rb
   50 /usr/lib/ruby/vendor_ruby/did_you_mean/formatters/plain_formatter.rb
   51 /usr/lib/ruby/vendor_ruby/did_you_mean.rb
   52 /usr/lib/ruby/vendor_ruby/bundler/version.rb
   53 /usr/lib/ruby/vendor_ruby/bundler/compatibility_guard.rb
   54 /usr/lib/x86_64-linux-gnu/ruby/2.5.0/etc.so
   55 /usr/lib/ruby/vendor_ruby/bundler/vendor/fileutils/lib/fileutils.rb
   56 /usr/lib/ruby/vendor_ruby/bundler/vendored_fileutils.rb
   57 /usr/lib/x86_64-linux-gnu/ruby/2.5.0/pathname.so
   58 /usr/lib/ruby/2.5.0/pathname.rb
   59 /usr/lib/ruby/vendor_ruby/bundler/errors.rb
   60 /usr/lib/ruby/vendor_ruby/bundler/environment_preserver.rb
   61 /usr/lib/ruby/vendor_ruby/bundler/plugin/api.rb
   62 /usr/lib/ruby/vendor_ruby/bundler/plugin.rb
   63 /usr/lib/ruby/2.5.0/rubygems/util.rb
   64 /usr/lib/ruby/2.5.0/rubygems/source/git.rb
   65 /usr/lib/ruby/2.5.0/rubygems/source/installed.rb
   66 /usr/lib/ruby/2.5.0/rubygems/source/specific_file.rb
   67 /usr/lib/ruby/2.5.0/rubygems/source/local.rb
   68 /usr/lib/ruby/2.5.0/rubygems/source/lock.rb
   69 /usr/lib/ruby/2.5.0/rubygems/source/vendor.rb
   70 /usr/lib/ruby/2.5.0/rubygems/source.rb
   71 /usr/lib/ruby/vendor_ruby/bundler/gem_helpers.rb
   72 /usr/lib/ruby/vendor_ruby/bundler/match_platform.rb
   73 /usr/lib/ruby/vendor_ruby/bundler/rubygems_ext.rb
   74 /usr/lib/ruby/2.5.0/rubygems/user_interaction.rb
   75 /usr/lib/ruby/2.5.0/rubygems/config_file.rb
   76 /usr/lib/ruby/vendor_ruby/bundler/rubygems_integration.rb
   77 /usr/lib/ruby/vendor_ruby/bundler/constants.rb
   78 /usr/lib/ruby/vendor_ruby/bundler/current_ruby.rb
   79 /usr/lib/ruby/vendor_ruby/bundler/build_metadata.rb
   80 /usr/lib/ruby/vendor_ruby/bundler.rb
   81 /usr/lib/ruby/2.5.0/cgi/core.rb
   82 /usr/lib/x86_64-linux-gnu/ruby/2.5.0/cgi/escape.so
   83 /usr/lib/ruby/2.5.0/cgi/util.rb
   84 /usr/lib/ruby/2.5.0/cgi/cookie.rb
   85 /usr/lib/ruby/2.5.0/cgi.rb
   86 /usr/lib/ruby/2.5.0/set.rb
   87 /usr/lib/ruby/vendor_ruby/thor/command.rb
   88 /usr/lib/ruby/vendor_ruby/thor/core_ext/hash_with_indifferent_access.rb
   89 /usr/lib/ruby/vendor_ruby/thor/core_ext/ordered_hash.rb
   90 /usr/lib/ruby/vendor_ruby/thor/error.rb
   91 /usr/lib/ruby/vendor_ruby/thor/invocation.rb
   92 /usr/lib/ruby/vendor_ruby/thor/parser/argument.rb
   93 /usr/lib/ruby/vendor_ruby/thor/parser/arguments.rb
   94 /usr/lib/ruby/vendor_ruby/thor/parser/option.rb
   95 /usr/lib/ruby/vendor_ruby/thor/parser/options.rb
   96 /usr/lib/ruby/vendor_ruby/thor/parser.rb
   97 /usr/lib/ruby/vendor_ruby/thor/shell.rb
   98 /usr/lib/ruby/vendor_ruby/thor/line_editor/basic.rb
   99 /usr/lib/x86_64-linux-gnu/ruby/2.5.0/readline.so
  100 /usr/lib/ruby/vendor_ruby/thor/line_editor/readline.rb
  101 /usr/lib/ruby/vendor_ruby/thor/line_editor.rb
  102 /usr/lib/ruby/vendor_ruby/thor/util.rb
  103 /usr/lib/ruby/vendor_ruby/thor/base.rb
  104 /usr/lib/ruby/vendor_ruby/thor.rb
  105 /usr/lib/ruby/vendor_ruby/bundler/vendored_thor.rb
  106 /usr/lib/ruby/vendor_ruby/bundler/friendly_errors.rb
  107 /usr/lib/ruby/vendor_ruby/bundler/cli/common.rb
  108 /usr/lib/ruby/vendor_ruby/bundler/settings.rb
  109 /usr/lib/ruby/vendor_ruby/bundler/feature_flag.rb
  110 /usr/lib/ruby/vendor_ruby/bundler/shared_helpers.rb
  111 /usr/lib/ruby/2.5.0/rubygems/ext/builder.rb
  112 /usr/lib/ruby/vendor_ruby/bundler/cli/plugin.rb
  113 /usr/lib/ruby/vendor_ruby/bundler/cli.rb
  114 /usr/lib/ruby/2.5.0/fileutils.rb
  115 /usr/lib/ruby/2.5.0/tmpdir.rb
  116 /usr/lib/ruby/2.5.0/tempfile.rb
  117 /usr/lib/x86_64-linux-gnu/ruby/2.5.0/io/console.so
  118 /usr/lib/ruby/vendor_ruby/thor/shell/basic.rb
  119 /usr/lib/ruby/vendor_ruby/thor/shell/color.rb
  120 /usr/lib/ruby/vendor_ruby/bundler/ui.rb
  121 /usr/lib/ruby/vendor_ruby/bundler/ui/silent.rb
  122 /usr/lib/ruby/vendor_ruby/bundler/ui/rg_proxy.rb
  123 /usr/lib/ruby/vendor_ruby/bundler/ui/shell.rb
  124 /usr/lib/ruby/vendor_ruby/bundler/cli/exec.rb
  125 /usr/lib/ruby/2.5.0/rubygems/bundler_version_finder.rb
  126 /usr/lib/ruby/vendor_ruby/bundler/source.rb
  127 /usr/lib/ruby/vendor_ruby/bundler/source/path.rb
  128 /usr/lib/ruby/vendor_ruby/bundler/source/git.rb
  129 /usr/lib/ruby/vendor_ruby/bundler/source/rubygems.rb
  130 /usr/lib/ruby/vendor_ruby/bundler/lockfile_parser.rb
  131 /usr/lib/ruby/vendor_ruby/bundler/definition.rb
  132 /usr/lib/ruby/vendor_ruby/bundler/dependency.rb
  133 /usr/lib/ruby/vendor_ruby/bundler/ruby_dsl.rb
  134 /usr/lib/ruby/vendor_ruby/bundler/dsl.rb
  135 /usr/lib/ruby/vendor_ruby/bundler/source_list.rb
  136 /usr/lib/ruby/vendor_ruby/bundler/source/metadata.rb
  137 /usr/lib/ruby/vendor_ruby/bundler/lazy_specification.rb
  138 /usr/lib/ruby/vendor_ruby/bundler/index.rb
  139 /usr/lib/ruby/2.5.0/tsort.rb
  140 /usr/lib/ruby/2.5.0/forwardable/impl.rb
  141 /usr/lib/ruby/2.5.0/forwardable.rb
  142 /usr/lib/ruby/vendor_ruby/bundler/spec_set.rb
  143 /usr/lib/ruby/vendor_ruby/molinillo/compatibility.rb
  144 /usr/lib/ruby/vendor_ruby/molinillo/gem_metadata.rb
  145 /usr/lib/ruby/vendor_ruby/molinillo/delegates/specification_provider.rb
  146 /usr/lib/ruby/vendor_ruby/molinillo/errors.rb
  147 /usr/lib/ruby/vendor_ruby/molinillo/dependency_graph/action.rb
  148 /usr/lib/ruby/vendor_ruby/molinillo/dependency_graph/add_edge_no_circular.rb
  149 /usr/lib/ruby/vendor_ruby/molinillo/dependency_graph/add_vertex.rb
  150 /usr/lib/ruby/vendor_ruby/molinillo/dependency_graph/delete_edge.rb
  151 /usr/lib/ruby/vendor_ruby/molinillo/dependency_graph/detach_vertex_named.rb
  152 /usr/lib/ruby/vendor_ruby/molinillo/dependency_graph/set_payload.rb
  153 /usr/lib/ruby/vendor_ruby/molinillo/dependency_graph/tag.rb
  154 /usr/lib/ruby/vendor_ruby/molinillo/dependency_graph/log.rb
  155 /usr/lib/ruby/vendor_ruby/molinillo/dependency_graph/vertex.rb
  156 /usr/lib/ruby/vendor_ruby/molinillo/dependency_graph.rb
  157 /usr/lib/ruby/vendor_ruby/molinillo/state.rb
  158 /usr/lib/ruby/vendor_ruby/molinillo/modules/specification_provider.rb
  159 /usr/lib/ruby/vendor_ruby/molinillo/delegates/resolution_state.rb
  160 /usr/lib/ruby/vendor_ruby/molinillo/resolution.rb
  161 /usr/lib/ruby/vendor_ruby/molinillo/resolver.rb
  162 /usr/lib/ruby/vendor_ruby/molinillo/modules/ui.rb
  163 /usr/lib/ruby/vendor_ruby/molinillo.rb
  164 /usr/lib/ruby/vendor_ruby/bundler/vendored_molinillo.rb
  165 /usr/lib/ruby/vendor_ruby/bundler/resolver/spec_group.rb
  166 /usr/lib/ruby/vendor_ruby/bundler/resolver.rb
  167 /usr/lib/ruby/vendor_ruby/bundler/gem_version_promoter.rb
  168 /usr/lib/ruby/vendor_ruby/bundler/source/gemspec.rb
  169 /usr/lib/ruby/vendor_ruby/bundler/runtime.rb
  170 /usr/lib/ruby/vendor_ruby/bundler/dep_proxy.rb
  171 /usr/lib/ruby/vendor_ruby/bundler/remote_specification.rb
  172 /usr/lib/ruby/vendor_ruby/bundler/stub_specification.rb
  173 /usr/lib/ruby/vendor_ruby/bundler/endpoint_specification.rb
  174 /usr/lib/ruby/vendor_ruby/bundler/ruby_version.rb
  175 /usr/lib/ruby/vendor_ruby/bundler/setup.rb
  176 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi_c.so
  177 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi/platform.rb
  178 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi/types.rb
  179 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi/library.rb
  180 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi/errno.rb
  181 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi/pointer.rb
  182 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi/memorypointer.rb
  183 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi/struct_layout_builder.rb
  184 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi/struct.rb
  185 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi/union.rb
  186 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi/managedstruct.rb
  187 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi/callback.rb
  188 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi/io.rb
  189 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi/autopointer.rb
  190 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi/variadic.rb
  191 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi/enum.rb
  192 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi/ffi.rb
  193 /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi.rb
  194 /checkout/embug-1203/embuga_ffi.rb
  195 /var/lib/gems/2.5.0/gems/eventmachine-1.2.7/lib/rubyeventmachine.so

* Process memory map:

55e9e79a2000-55e9e79a3000 r-xp 00000000 08:01 3672492                    /usr/bin/ruby2.5
55e9e7ba2000-55e9e7ba3000 r--p 00000000 08:01 3672492                    /usr/bin/ruby2.5
55e9e7ba3000-55e9e7ba4000 rw-p 00001000 08:01 3672492                    /usr/bin/ruby2.5
55e9e7f67000-55e9e8a62000 rw-p 00000000 00:00 0                          [heap]
7fd0f49e6000-7fd0f4b6c000 r--s 00000000 08:01 3803809                    /usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.25
7fd0f4b6c000-7fd0f5a8e000 r--s 00000000 08:01 1048935                    /usr/lib/debug/lib/x86_64-linux-gnu/libc-2.27.so
7fd0f5a8e000-7fd0f5c7e000 r--s 00000000 08:01 3150403                    /lib/x86_64-linux-gnu/libc-2.27.so
7fd0f5c7e000-7fd0f5f1f000 r--s 00000000 08:01 3803801                    /usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5.1
7fd0f5f1f000-7fd0f6098000 r-xp 00000000 08:01 3803809                    /usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.25
7fd0f6098000-7fd0f6298000 ---p 00179000 08:01 3803809                    /usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.25
7fd0f6298000-7fd0f62a2000 r--p 00179000 08:01 3803809                    /usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.25
7fd0f62a2000-7fd0f62a4000 rw-p 00183000 08:01 3803809                    /usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.25
7fd0f62a4000-7fd0f62a8000 rw-p 00000000 00:00 0
7fd0f62a8000-7fd0f62c9000 r-xp 00000000 08:01 1049793                    /var/lib/gems/2.5.0/gems/eventmachine-1.2.7/lib/rubyeventmachine.so
7fd0f62c9000-7fd0f64c8000 ---p 00021000 08:01 1049793                    /var/lib/gems/2.5.0/gems/eventmachine-1.2.7/lib/rubyeventmachine.so
7fd0f64c8000-7fd0f64ca000 r--p 00020000 08:01 1049793                    /var/lib/gems/2.5.0/gems/eventmachine-1.2.7/lib/rubyeventmachine.so
7fd0f64ca000-7fd0f64cb000 rw-p 00022000 08:01 1049793                    /var/lib/gems/2.5.0/gems/eventmachine-1.2.7/lib/rubyeventmachine.so
7fd0f64cb000-7fd0f64d2000 r-xp 00000000 08:01 3150468                    /lib/x86_64-linux-gnu/librt-2.27.so
7fd0f64d2000-7fd0f66d1000 ---p 00007000 08:01 3150468                    /lib/x86_64-linux-gnu/librt-2.27.so
7fd0f66d1000-7fd0f66d2000 r--p 00006000 08:01 3150468                    /lib/x86_64-linux-gnu/librt-2.27.so
7fd0f66d2000-7fd0f66d3000 rw-p 00007000 08:01 3150468                    /lib/x86_64-linux-gnu/librt-2.27.so
7fd0f66d3000-7fd0f66ea000 r-xp 00000000 08:01 3672332                    /lib/x86_64-linux-gnu/libgcc_s.so.1
7fd0f66ea000-7fd0f68e9000 ---p 00017000 08:01 3672332                    /lib/x86_64-linux-gnu/libgcc_s.so.1
7fd0f68e9000-7fd0f68ea000 r--p 00016000 08:01 3672332                    /lib/x86_64-linux-gnu/libgcc_s.so.1
7fd0f68ea000-7fd0f68eb000 rw-p 00017000 08:01 3672332                    /lib/x86_64-linux-gnu/libgcc_s.so.1
7fd0f68eb000-7fd0f6917000 r-xp 00000000 08:01 3803670                    /usr/lib/x86_64-linux-gnu/libc++abi.so.1.0
7fd0f6917000-7fd0f6b17000 ---p 0002c000 08:01 3803670                    /usr/lib/x86_64-linux-gnu/libc++abi.so.1.0
7fd0f6b17000-7fd0f6b1a000 r--p 0002c000 08:01 3803670                    /usr/lib/x86_64-linux-gnu/libc++abi.so.1.0
7fd0f6b1a000-7fd0f6b1b000 rw-p 0002f000 08:01 3803670                    /usr/lib/x86_64-linux-gnu/libc++abi.so.1.0
7fd0f6b1b000-7fd0f6bd5000 r-xp 00000000 08:01 3803668                    /usr/lib/x86_64-linux-gnu/libc++.so.1.0
7fd0f6bd5000-7fd0f6dd5000 ---p 000ba000 08:01 3803668                    /usr/lib/x86_64-linux-gnu/libc++.so.1.0
7fd0f6dd5000-7fd0f6dda000 r--p 000ba000 08:01 3803668                    /usr/lib/x86_64-linux-gnu/libc++.so.1.0
7fd0f6dda000-7fd0f6ddb000 rw-p 000bf000 08:01 3803668                    /usr/lib/x86_64-linux-gnu/libc++.so.1.0
7fd0f6ddb000-7fd0f6dde000 rw-p 00000000 00:00 0
7fd0f6dde000-7fd0f6de1000 r-xp 00000000 00:51 6498736                    /checkout/embug-1203/libembuga/libembuga.so
7fd0f6de1000-7fd0f6fe0000 ---p 00003000 00:51 6498736                    /checkout/embug-1203/libembuga/libembuga.so
7fd0f6fe0000-7fd0f6fe1000 r--p 00002000 00:51 6498736                    /checkout/embug-1203/libembuga/libembuga.so
7fd0f6fe1000-7fd0f6fe2000 rw-p 00003000 00:51 6498736                    /checkout/embug-1203/libembuga/libembuga.so
7fd0f6fe2000-7fd0f7004000 r-xp 00000000 08:01 530773                     /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi_c.so
7fd0f7004000-7fd0f7204000 ---p 00022000 08:01 530773                     /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi_c.so
7fd0f7204000-7fd0f7205000 r--p 00022000 08:01 530773                     /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi_c.so
7fd0f7205000-7fd0f7206000 rw-p 00023000 08:01 530773                     /var/lib/gems/2.5.0/gems/ffi-1.9.25/lib/ffi_c.so
7fd0f7206000-7fd0f720a000 r-xp 00000000 08:01 3804442                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/io/console.so
7fd0f720a000-7fd0f7409000 ---p 00004000 08:01 3804442                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/io/console.so
7fd0f7409000-7fd0f740a000 r--p 00003000 08:01 3804442                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/io/console.so
7fd0f740a000-7fd0f740b000 rw-p 00004000 08:01 3804442                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/io/console.so
7fd0f740b000-7fd0f7430000 r-xp 00000000 08:01 3150483                    /lib/x86_64-linux-gnu/libtinfo.so.5.9
7fd0f7430000-7fd0f7630000 ---p 00025000 08:01 3150483                    /lib/x86_64-linux-gnu/libtinfo.so.5.9
7fd0f7630000-7fd0f7634000 r--p 00025000 08:01 3150483                    /lib/x86_64-linux-gnu/libtinfo.so.5.9
7fd0f7634000-7fd0f7635000 rw-p 00029000 08:01 3150483                    /lib/x86_64-linux-gnu/libtinfo.so.5.9
7fd0f7635000-7fd0f7676000 r-xp 00000000 08:01 3672338                    /lib/x86_64-linux-gnu/libreadline.so.7.0
7fd0f7676000-7fd0f7875000 ---p 00041000 08:01 3672338                    /lib/x86_64-linux-gnu/libreadline.so.7.0
7fd0f7875000-7fd0f7877000 r--p 00040000 08:01 3672338                    /lib/x86_64-linux-gnu/libreadline.so.7.0
7fd0f7877000-7fd0f787d000 rw-p 00042000 08:01 3672338                    /lib/x86_64-linux-gnu/libreadline.so.7.0
7fd0f787d000-7fd0f787e000 rw-p 00000000 00:00 0
7fd0f787e000-7fd0f7885000 r-xp 00000000 08:01 3804460                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/readline.so
7fd0f7885000-7fd0f7a85000 ---p 00007000 08:01 3804460                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/readline.so
7fd0f7a85000-7fd0f7a86000 r--p 00007000 08:01 3804460                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/readline.so
7fd0f7a86000-7fd0f7a87000 rw-p 00008000 08:01 3804460                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/readline.so
7fd0f7a87000-7fd0f7a8a000 r-xp 00000000 08:01 3804363                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/cgi/escape.so
7fd0f7a8a000-7fd0f7c89000 ---p 00003000 08:01 3804363                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/cgi/escape.so
7fd0f7c89000-7fd0f7c8a000 r--p 00002000 08:01 3804363                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/cgi/escape.so
7fd0f7c8a000-7fd0f7c8b000 rw-p 00003000 08:01 3804363                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/cgi/escape.so
7fd0f7c8b000-7fd0f7c92000 r-xp 00000000 08:01 3804452                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/pathname.so
7fd0f7c92000-7fd0f7e91000 ---p 00007000 08:01 3804452                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/pathname.so
7fd0f7e91000-7fd0f7e92000 r--p 00006000 08:01 3804452                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/pathname.so
7fd0f7e92000-7fd0f7e93000 rw-p 00007000 08:01 3804452                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/pathname.so
7fd0f7e93000-7fd0f7e99000 r-xp 00000000 08:01 3804436                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/etc.so
7fd0f7e99000-7fd0f8098000 ---p 00006000 08:01 3804436                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/etc.so
7fd0f8098000-7fd0f8099000 r--p 00005000 08:01 3804436                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/etc.so
7fd0f8099000-7fd0f809a000 rw-p 00006000 08:01 3804436                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/etc.so
7fd0f809a000-7fd0f80a1000 r-xp 00000000 08:01 3804464                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/stringio.so
7fd0f80a1000-7fd0f82a1000 ---p 00007000 08:01 3804464                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/stringio.so
7fd0f82a1000-7fd0f82a2000 r--p 00007000 08:01 3804464                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/stringio.so
7fd0f82a2000-7fd0f82a3000 rw-p 00008000 08:01 3804464                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/stringio.so
7fd0f82a3000-7fd0f82a5000 r-xp 00000000 08:01 3804422                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/enc/trans/transdb.so
7fd0f82a5000-7fd0f84a5000 ---p 00002000 08:01 3804422                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/enc/trans/transdb.so
7fd0f84a5000-7fd0f84a6000 r--p 00002000 08:01 3804422                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/enc/trans/transdb.so
7fd0f84a6000-7fd0f84a7000 rw-p 00003000 08:01 3804422                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/enc/trans/transdb.so
7fd0f84a7000-7fd0f84a9000 r-xp 00000000 08:01 3804379                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/enc/encdb.so
7fd0f84a9000-7fd0f86a8000 ---p 00002000 08:01 3804379                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/enc/encdb.so
7fd0f86a8000-7fd0f86a9000 r--p 00001000 08:01 3804379                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/enc/encdb.so
7fd0f86a9000-7fd0f86aa000 rw-p 00002000 08:01 3804379                    /usr/lib/x86_64-linux-gnu/ruby/2.5.0/enc/encdb.so
7fd0f86aa000-7fd0f8847000 r-xp 00000000 08:01 3150428                    /lib/x86_64-linux-gnu/libm-2.27.so
7fd0f8847000-7fd0f8a46000 ---p 0019d000 08:01 3150428                    /lib/x86_64-linux-gnu/libm-2.27.so
7fd0f8a46000-7fd0f8a47000 r--p 0019c000 08:01 3150428                    /lib/x86_64-linux-gnu/libm-2.27.so
7fd0f8a47000-7fd0f8a48000 rw-p 0019d000 08:01 3150428                    /lib/x86_64-linux-gnu/libm-2.27.so
7fd0f8a48000-7fd0f8a51000 r-xp 00000000 08:01 3150411                    /lib/x86_64-linux-gnu/libcrypt-2.27.so
7fd0f8a51000-7fd0f8c50000 ---p 00009000 08:01 3150411                    /lib/x86_64-linux-gnu/libcrypt-2.27.so
7fd0f8c50000-7fd0f8c51000 r--p 00008000 08:01 3150411                    /lib/x86_64-linux-gnu/libcrypt-2.27.so
7fd0f8c51000-7fd0f8c52000 rw-p 00009000 08:01 3150411                    /lib/x86_64-linux-gnu/libcrypt-2.27.so
7fd0f8c52000-7fd0f8c80000 rw-p 00000000 00:00 0
7fd0f8c80000-7fd0f8c83000 r-xp 00000000 08:01 3150413                    /lib/x86_64-linux-gnu/libdl-2.27.so
7fd0f8c83000-7fd0f8e82000 ---p 00003000 08:01 3150413                    /lib/x86_64-linux-gnu/libdl-2.27.so
7fd0f8e82000-7fd0f8e83000 r--p 00002000 08:01 3150413                    /lib/x86_64-linux-gnu/libdl-2.27.so
7fd0f8e83000-7fd0f8e84000 rw-p 00003000 08:01 3150413                    /lib/x86_64-linux-gnu/libdl-2.27.so
7fd0f8e84000-7fd0f8f03000 r-xp 00000000 08:01 3281088                    /usr/lib/x86_64-linux-gnu/libgmp.so.10.3.2
7fd0f8f03000-7fd0f9103000 ---p 0007f000 08:01 3281088                    /usr/lib/x86_64-linux-gnu/libgmp.so.10.3.2
7fd0f9103000-7fd0f9104000 r--p 0007f000 08:01 3281088                    /usr/lib/x86_64-linux-gnu/libgmp.so.10.3.2
7fd0f9104000-7fd0f9105000 rw-p 00080000 08:01 3281088                    /usr/lib/x86_64-linux-gnu/libgmp.so.10.3.2
7fd0f9105000-7fd0f911f000 r-xp 00000000 08:01 3150464                    /lib/x86_64-linux-gnu/libpthread-2.27.so
7fd0f911f000-7fd0f931e000 ---p 0001a000 08:01 3150464                    /lib/x86_64-linux-gnu/libpthread-2.27.so
7fd0f931e000-7fd0f931f000 r--p 00019000 08:01 3150464                    /lib/x86_64-linux-gnu/libpthread-2.27.so
7fd0f931f000-7fd0f9320000 rw-p 0001a000 08:01 3150464                    /lib/x86_64-linux-gnu/libpthread-2.27.so
7fd0f9320000-7fd0f9324000 rw-p 00000000 00:00 0
7fd0f9324000-7fd0f950b000 r-xp 00000000 08:01 3150403                    /lib/x86_64-linux-gnu/libc-2.27.so
7fd0f950b000-7fd0f970b000 ---p 001e7000 08:01 3150403                    /lib/x86_64-linux-gnu/libc-2.27.so
7fd0f970b000-7fd0f970f000 r--p 001e7000 08:01 3150403                    /lib/x86_64-linux-gnu/libc-2.27.so
7fd0f970f000-7fd0f9711000 rw-p 001eb000 08:01 3150403                    /lib/x86_64-linux-gnu/libc-2.27.so
7fd0f9711000-7fd0f9715000 rw-p 00000000 00:00 0
7fd0f9715000-7fd0f99af000 r-xp 00000000 08:01 3803801                    /usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5.1
7fd0f99af000-7fd0f9bae000 ---p 0029a000 08:01 3803801                    /usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5.1
7fd0f9bae000-7fd0f9bb4000 r--p 00299000 08:01 3803801                    /usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5.1
7fd0f9bb4000-7fd0f9bb5000 rw-p 0029f000 08:01 3803801                    /usr/lib/x86_64-linux-gnu/libruby-2.5.so.2.5.1
7fd0f9bb5000-7fd0f9bc5000 rw-p 00000000 00:00 0
7fd0f9bc5000-7fd0f9bec000 r-xp 00000000 08:01 3150385                    /lib/x86_64-linux-gnu/ld-2.27.so
7fd0f9c76000-7fd0f9c7b000 r--s 00000000 00:51 6498736                    /checkout/embug-1203/libembuga/libembuga.so
7fd0f9c7b000-7fd0f9c7d000 r--s 00000000 08:01 3672492                    /usr/bin/ruby2.5
7fd0f9c7d000-7fd0f9de6000 rw-p 00000000 00:00 0
7fd0f9de6000-7fd0f9de7000 r-xp 00000000 00:00 0
7fd0f9de7000-7fd0f9de8000 ---p 00000000 00:00 0
7fd0f9de8000-7fd0f9dec000 rw-p 00000000 00:00 0
7fd0f9dec000-7fd0f9ded000 r--p 00027000 08:01 3150385                    /lib/x86_64-linux-gnu/ld-2.27.so
7fd0f9ded000-7fd0f9dee000 rw-p 00028000 08:01 3150385                    /lib/x86_64-linux-gnu/ld-2.27.so
7fd0f9dee000-7fd0f9def000 rw-p 00000000 00:00 0
7ffcc0e1b000-7ffcc161a000 rw-p 00000000 00:00 0                          [stack]
7ffcc1792000-7ffcc1794000 r--p 00000000 00:00 0                          [vvar]
7ffcc1794000-7ffcc1796000 r-xp 00000000 00:00 0                          [vdso]
ffffffffff600000-ffffffffff601000 r-xp 00000000 00:00 0                  [vsyscall]


[NOTE]
You may have encountered a bug in the Ruby interpreter or extension libraries.
Bug reports are welcome.
For details: http://www.ruby-lang.org/bugreport.html

Aborted
```

Issue reproduced.

### Test 8. loading libembugb, then eventmachine (test_b_em.rb)

```
# bundle exec test_em_b.rb
47
Error!
-1
```

Expected.


### Test 9. loading eventmachine, then libemebugb (test_em_b.rb)

```
# bundle exec test_em_b.rb
47
Error!
-1
```

Expected.

## Conclusion

The segfault can only be reproduced when eventmachine is loaded after (order matters) a library linked against libc++. Further investigation is required to find the cause of this issue.
