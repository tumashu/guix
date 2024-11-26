(define-module (gnu packages dotnet)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages assembly)
  #:use-module (gnu packages bison)
  #:use-module (gnu packages check)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages flex)
  #:use-module (gnu packages gettext)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages base)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages bdw-gc)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages icu4c)
  #:use-module (gnu packages instrumentation)
  #:use-module (gnu packages kerberos)
  #:use-module (gnu packages libffi)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages photo)
  #:use-module (gnu packages texinfo)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages image)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages python)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages)
  #:use-module (guix modules)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system python)
  #:use-module (ice-9 match))

(define-public treecc
  (package
    (name "treecc")
    (version "0.3.10")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://download.savannah.gnu.org/releases/dotgnu-pnet/treecc-"
                    version ".tar.gz"))
              (sha256
               (base32
                "1rzgnspg2xccdq3qsx0vi3j28h4qkrzbrjnhzvnny34fjfk217ay"))))
    (build-system gnu-build-system)
    (home-page "https://www.gnu.org/software/dotgnu")
    (synopsis "Tree Compiler-Compiler")
    (description "The treecc program is designed to assist in the development
of compilers and other language-based tools.  It manages the generation of
code to handle abstract syntax trees and operations upon the trees.")
    (license license:gpl2+)))

;; Several improvements occurred past the 0.8.0 release that make it
;; easier to bootstrap mono.
(define-public pnet-git
  (let ((commit "3baf94734d8dc3fdabba68a8891e67a43ed6c4bd")
        (version "0.8.0")
        (revision "0"))
    (package
      (name "pnet-git")
      (version (git-version version revision commit))
      (source (origin
                (method git-fetch)
                (uri (git-reference
                      (url "https://git.savannah.gnu.org/git/dotgnu-pnet/pnet.git")
                      (commit commit)))
                (file-name (git-file-name name version))
                (sha256
                 (base32
                  "0vznvrgz8l0mpib1rz5v3clr7cn570vyp80f7f1jvzivnc1imzn6"))
                (modules '((guix build utils)))
                (snippet
                 #~(begin
                     (for-each delete-file-recursively '("libffi" "libgc"))
                     (for-each delete-file
                               (append
                                 (filter file-exists?
                                         '("compile"
                                           "configure"
                                           "config.guess"
                                           "config.sub"
                                           "depcomp"
                                           "install-sh"
                                           "ltconfig"
                                           "ltcf-c.sh"
                                           "ltmain.sh"))
                                 (find-files "." "Makefile(\\.in)?$")
                                 (find-files "." "_(grammar|scanner)\\.(c|h)$")))
                     ;; Fix to not require bundled dependencies
                     (substitute* "configure.in"
                       (("GCLIBS='.*libgc.a'") "GCLIBS='-lgc'")
                       ;; AC_SEARCH_LIBJIT checks hardcoded header locations
                       (("search_libjit=true")
                        (string-append "search_libjit=false\n"
                                       "JIT_LIBS=-ljit")))
                     (substitute* "Makefile.am"
                       (("OPT_SUBDIRS \\+= lib.*") ""))
                     (substitute* "support/hb_gc.c"
                       (("#include .*/libgc/include/gc.h.")
                        "#include <gc.h>")
                       (("#include .*/libgc/include/gc_typed.h.")
                        "#include <gc/gc_typed.h>"))
                     (substitute* (list "codegen/Makefile.am"
                                        "cscc/bf/Makefile.am"
                                        "cscc/csharp/Makefile.am"
                                        "cscc/c/Makefile.am"
                                        "cscc/java/Makefile.am")
                       ;; Generated files aren't prerequisites
                       (("TREECC_OUTPUT =.*") ""))
                     (substitute* "cscc/csharp/cs_grammar.y"
                       (("YYLEX") "yylex()"))
                     (substitute* "cscc/common/cc_main.h"
                       (("CCPreProc CCPreProcessorStream;" all)
                        (string-append "extern " all)))
                     (substitute* "csdoc/scanner.c"
                       (("int\ttoken;" all)
                        (string-append "extern " all)))
                     (substitute* "doc/cvmdoc.py"
                       (("python1.5")
                        "python"))
                     (substitute* "profiles/full"
                       ;; If this is left unmodified, it causes a segfault in
                       ;; pnetlib's tests.  Unrollers are somewhat
                       ;; architecture-specific anyway, and it will fall back
                       ;; to using GNU C's labels-as-values feature (it can be
                       ;; made to further fall back to fully
                       ;; standards-portable interpreter implementations).
                       (("IL_CONFIG_UNROLL=y")
                        "IL_CONFIG_UNROLL=n"))))
                (patches (search-patches "pnet-newer-libgc-fix.patch"
                                         "pnet-newer-texinfo-fix.patch"
                                         "pnet-fix-line-number-info.patch"
                                         "pnet-fix-off-by-one.patch"))))
      (build-system gnu-build-system)
      (native-inputs
       (list autoconf
             automake
             bison
             flex
             libatomic-ops
             libtool
             python-minimal-wrapper
             texinfo
             treecc))
      (inputs
       (cons* libffi
              libgc
              (if (supported-package? libjit)
                  (list libjit)
                  '())))
      (arguments
       (append (if (this-package-input "libjit")
                   (list #:configure-flags #~(list "--with-jit"))
                   '())
               (list #:make-flags
                     #~(list "CFLAGS=-O2 -g -Wno-pointer-to-int-cast"))))
      (native-search-paths
       (list (search-path-specification
              (variable "CSCC_LIB_PATH")
              (files (list "lib/cscc/lib")))))
      (home-page "http://www.gnu.org/software/dotgnu/html2.0/pnet.html")
      (synopsis "Compiler for the C# programming language")
      (description
       "The goal of this project is to build a suite of free software tools
to build and execute .NET applications, including a C# compiler,
assembler, disassembler, and runtime engine.")
      (license license:gpl2+))))

(define-public pnetlib-git
  (let ((version "0.8.0")
        (commit "c3c12b8b0c65f5482d03d6a4865f7670e98baf4c")
        (revision "0"))
    (package
      (name "pnetlib-git")
      (version (git-version version revision commit))
      (source (origin
                (method git-fetch)
                (uri (git-reference
                      (url
                       "https://git.savannah.gnu.org/git/dotgnu-pnet/pnetlib.git")
                      (commit commit)))
                (file-name (git-file-name name version))
                (sha256
                 (base32
                  "04dikki3lr3m1cacirld90rpi95656b2y2mc5rkycb7s0yfdz1nk"))
                (modules '((guix build utils)))
                (snippet
                 #~(begin
                     (for-each delete-file
                               (append (filter file-exists?
                                               '("configure"
                                                 "config.guess"
                                                 "config.sub"
                                                 "install-sh"
                                                 "ltmain.sh"))
                                       (find-files "." "Makefile(\\.in)?$")))
                     (substitute* (find-files "tests" "^Makefile\\.am$")
                       (("TESTS_ENVIRONMENT.*")
                        (string-append
                         "LOG_COMPILER = $(SHELL)\n"
                         "AM_LOG_FLAGS = $(top_builddir)/tools/run_test.sh"
                         " $(top_builddir)")))
                     (substitute* "tools/run_test.sh.in"
                       (("en_US") "en_US.utf8"))
                     (substitute* "tools/wrapper.sh.in"
                       (("exec .LN_S clrwrap ..1.")
                        (string-append
                         "echo '#!@SHELL@' >> $1\n"
                         "echo exec $CLRWRAP"
                         " $(dirname $(dirname $1))"
                         "/lib/cscc/lib/$(basename $1).exe >> $1\n"
                         "chmod +x $1")))))))
      (build-system gnu-build-system)
      (arguments
       (list
        #:make-flags #~(list "CFLAGS=-O2 -g -Wno-pointer-to-int-cast")
        #:tests? (and (not (%current-target-system))
                      (not (target-aarch64?)))
        #:phases
        #~(modify-phases %standard-phases
            (add-after 'unpack 'disable-x11-tests
              (lambda _
                (substitute* "tests/Makefile.am"
                  ;; This actually always fails, for a number of
                  ;; reasons:
                  ;; 1. We have no libx11 present, nor do we have an X display
                  ;;    present.  This will cause libXsharpSupport.so to be
                  ;;    built with only shims that fail at runtime.
                  ;; 2. No mechanism is provided for
                  ;;    tests/System.Windows.Forms/TestForms.dll to find
                  ;;    libXsharpSupport.so, which seems to sit at
                  ;;    Xsharp/.libs/libXsharpSupport.so.
                  ;; With a libjit pnet,
                  ;; System.Drawing.Toolkit.ToolkitHandler.CreateDefaultToolkit
                  ;; throws ArgumentNullException when invoking Assembly.Load,
                  ;; while a cvm pnet instead succeeds temporarily, but then
                  ;; fails when invoking
                  ;; System.Drawing.Toolkit.DrawingToolkit..ctor.  For some
                  ;; reason this results in csunit passing the former and
                  ;; failing the latter.
                  (("System\\.Windows\\.Forms") "")))))))
      (native-inputs
       (list autoconf automake libtool treecc))
      (inputs
       (list pnet-git))
      (home-page "http://www.gnu.org/software/dotgnu/html2.0/pnet.html")
      (synopsis "Libraries for the C# programming language")
      (description
       "DotGNU Portable.NET Library contains an implementation of the C# library,
for use with .NET-capable runtime engines and applications.")
      (license license:gpl2+))))

(define prepare-mono-source-0
  #~((when (file-exists? "configure")
       (delete-file "configure"))
     (when (file-exists? "libgc")
       (delete-file-recursively "libgc"))
     ;; just to be sure
     (for-each delete-file
               (find-files "." "\\.(dll|exe|DLL|EXE|so)$"))
     ;; We deleted docs/AgilityPack.dll earlier (if it existed), and it's
     ;; required for building the documentation, so skip building the
     ;; documentation.  According to docs/README, "the sources to this DLL
     ;; live in GNOME CVS module beagle/Filters/AgilityPack".
     (substitute* "Makefile.am"
       (("^(|DIST_|MOONLIGHT_|MONOTOUCH_)SUBDIRS =.*" all)
        (string-replace-substring
         (string-replace-substring
          (string-replace-substring all " docs" "")
          " $(libgc_dir)" "")
         " libgc" "")))))

;; A lot of the fixes are shared between many versions, and it doesn't hurt to
;; apply them to versions before or after they are necessary, so just include
;; them all.
(define prepare-mono-source
  #~(begin
      #$@prepare-mono-source-0
      (substitute* (filter file-exists?
                           '("configure.in"
                             "configure.ac"))
        (("int f = isinf \\(1\\);")
         "int f = isinf (1.0);"))
      ;; makedev is in <sys/sysmacros.h> now.  Include it.
      (substitute* "mono/io-layer/processes.c"
        (("#ifdef HAVE_SYS_MKDEV_H") "#if 1")
        (("sys/mkdev.h") "sys/sysmacros.h"))
      (substitute* (filter file-exists? '("mono/metadata/boehm-gc.c"))
        (("GC_set_finalizer_notify_proc")
         "GC_set_await_finalize_proc")
        (("GC_toggleref_register_callback")
         "GC_set_toggleref_func"))
      (substitute* (filter file-exists? '("mono/utils/mono-compiler.h"))
        (("static __thread gpointer x MONO_TLS_FAST")
         "static __thread gpointer x __attribute__((used))"))
      ;; Since the time the old mono versions were written at, gcc has started
      ;; removing more things it thinks are unused (for example because they
      ;; are only referenced in inline assembly of some sort).
      (substitute* (filter file-exists? '("mono/metadata/sgen-alloc.c"))
        (("static __thread char \\*\\*tlab_next_addr")
         "static __thread char **tlab_next_addr __attribute__((used))"))
      (substitute* (filter file-exists? '("mono/utils/mono-compiler.h"))
        (("#define MONO_TLS_FAST ")
         "#define MONO_TLS_FAST __attribute__((used)) "))))

(define-public mono-1.2.6
  (package
    (version "1.2.6")
    (name "mono")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "http://download.mono-project.com/sources/mono/"
                    "mono-" version ".tar.bz2"))
              (sha256
               (base32 "03sn7wyvrjkkkbrqajpmqifxfn83p30qprizpb3m6c5cdhwlzk14"))
              (modules '((guix build utils)
                         (ice-9 string-fun)))
              (snippet #~(begin
                           #$prepare-mono-source
                           (with-directory-excursion
                             "mcs/class/System/System.Text.RegularExpressions"
                             (delete-file "BaseMachine.cs")
                             ;; Can't patch a file with different line endings,
                             ;; so the patch creates a new one, and we overwrite
                             ;; the old one here.
                             (rename-file "BaseMachine.cs-2"
                                          "BaseMachine.cs"))))
              (patches (search-patches "mono-1.2.6-bootstrap.patch"))))
    (build-system gnu-build-system)
    (native-inputs
     (list autoconf
           automake
           bison
           libtool
           pnet-git
           pnetlib-git
           pkg-config))
    (inputs
     (list glib
           libgc
           libx11
           zlib))
    (arguments
     (list
      #:configure-flags #~(list "--with-gc=boehm")
      #:make-flags #~(list (string-append "EXTERNAL_MCS="
                                          #+(this-package-native-input "pnet-git")
                                          "/bin/cscc")
                           (string-append "EXTERNAL_RUNTIME="
                                          #+(this-package-native-input "pnet-git")
                                          "/bin/ilrun")
                           "CFLAGS=-O2 -g -DARG_MAX=500"
                           #$(string-append "CC=" (cc-for-target))
                           "V=1")
      ;; build fails nondeterministically without this
      #:parallel-build? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'set-env
            (lambda _
              ;; All tests under mcs/class fail trying to access $HOME
              (setenv "HOME" "/tmp")
              ;; ZIP files have "DOS time" which starts in Jan 1980.
              (setenv "SOURCE_DATE_EPOCH" "315532800"))))
      ;; System.Object isn't marked as serializable because it causes issues
      ;; with compiling with pnet (circular class reference between Object and
      ;; SerializableAttribute), and this causes tests to fail.
      #:tests? #f))
    (native-search-paths
     (list (search-path-specification
            (variable "MONO_PATH")
            (files (list "lib/mono")))))
    (synopsis "Compiler and libraries for the C# programming language")
    (description "Mono is a compiler, vm, debugger and set of libraries for C#
a C-style programming language from Microsoft that is very similar to Java.")
    (home-page "https://www.mono-project.com/")
    ;; See ./LICENSE
    (license (list
              ;; most of mcs/tools, mono/man, most of mcs/class, tests by
              ;; default, mono/eglib
              license:x11
              ;; mcs/mcs, mcs/gmcs, some of mcs/tools
              license:gpl1+ ;; note: ./mcs/LICENSE.GPL specifies no version
              ;; mono/mono (the mono VM, I think they meant mono/mini)
              license:lgpl2.0+ ;; note: ./mcs/LICENSE.LGPL specifies no version
              ;; mcs/jay
              license:bsd-4))))

(define-public mono-1.9.1
  (package
    (inherit mono-1.2.6)
    (version "1.9.1")
    (name "mono")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://gitlab.winehq.org/mono/mono.git")
                    (commit "mono-1.9.1.1")))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "0s1n3zdhc2alk9smxfdl1kjz7lz2p19gs0ks4hgr864jlmf13bws"))
              (modules '((guix build utils)
                         (ice-9 string-fun)))
              (snippet prepare-mono-source)
              (patches (search-patches
                         "mono-1.9.1-fixes.patch"
                         "mono-1.9.1-add-MONO_CREATE_IMAGE_VERSION.patch"))))
    (native-inputs
     (modify-inputs (package-native-inputs mono-1.2.6)
       (delete "pnet-git")
       (delete "pnetlib-git")
       (prepend mono-1.2.6)
       (append which)
       ;; needed for tests
       (append perl)))
    (arguments
     (substitute-keyword-arguments (package-arguments mono-1.2.6)
       ((#:make-flags _ #f)
        #~(list #$(string-append "CC=" (cc-for-target)) "V=1"))
       ((#:phases phases #~%standard-phases)
        #~(modify-phases #$phases
            (add-before 'configure 'set-cflags
              (lambda _
                ;; apparently can't be set via make flags in this version
                (let ((original (getenv "CFLAGS")))
                  (setenv "CFLAGS" (string-append (or original "")
                                                  (if original " " "")
                                                  "-DARG_MAX=500")))))
            (add-before 'configure 'set-create-image-version
              (lambda _
                ;; pnet produces v2.x assemblies.  Mono does this weird thing
                ;; where it always produces assemblies of the same version as
                ;; the runtime that is running it, which is based on the
                ;; version of the assembly that it loaded, which is based on
                ;; what it decided for the previous compiler... on and on all
                ;; the way back to pnet.  This breaks that chain, because
                ;; otherwise it ends up compiling the initial mcs against .NET
                ;; 2.0 libraries and then running with .NET 1.0 libraries.
                (setenv "MONO_CREATE_IMAGE_VERSION" "v1.1.4322")))
            (add-after 'unpack 'patch-test-driver-shebang
              (lambda _
                (patch-shebang "mono/tests/test-driver")))))
       ((#:tests? _ #f) #f)
       ((#:parallel-tests? _ #f) #f)))))

(define-public mono-2.4.2
  (package
    (inherit mono-1.9.1)
    (version "2.4.2.3")
    (name "mono")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://gitlab.winehq.org/mono/mono.git")
                    (commit (string-append
                              "mono-" (string-replace-substring version "." "-")))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "0mnrk17rd9c5rh30dh82a39c9ak1ns998b41ivprvy7m068skpda"))
              (modules '((guix build utils)
                         (ice-9 string-fun)))
              (snippet prepare-mono-source)
              (patches (search-patches "mono-2.4.2.3-fixes.patch"))))
    (native-inputs (modify-inputs (package-native-inputs mono-1.9.1)
                     (replace "mono" mono-1.9.1)))
    (inputs (modify-inputs (package-inputs mono-1.9.1)
              (append gettext-minimal)))
    (arguments
     (substitute-keyword-arguments (package-arguments mono-1.9.1)
       ((#:tests? _ #f)
        ;; When it tries building iltests.il in mono/mini, it gets: error
        ;; CS0006: cannot find metadata file `TestDriver.dll'.  It builds fine
        ;; outside of the build environment, but later tests fail, and I can't
        ;; be bothered to figure out what's causing ilasm to not find
        ;; TestDriver.dll.
        #f)
       ((#:phases phases #~%standard-phases)
        #~(modify-phases #$phases
            (add-before 'bootstrap 'patch-sub-autogen.sh-shebang
              (lambda _
                (patch-shebang "eglib/autogen.sh")))))))
    (license (list
              ;; most of mcs/tools, mono/man, most of mcs/class, tests by
              ;; default, mono/eglib
              ;; mcs/mcs, mcs/gmcs (dual-licensed GPL)
              ;; samples
              license:x11
              ;; mcs/mcs, mcs/gmcs (dual-licensed X11)
              ;; some of mcs/tools
              license:gpl1+ ;; note: ./mcs/LICENSE.GPL specifies no version
              ;; mono/mono (the mono VM, I think they meant mono/mini)
              license:lgpl2.0+ ;; note: ./mcs/LICENSE.LGPL specifies no version
              ;; mcs/jay
              license:bsd-4))))

(define-public mono-2.6.4
  (package
    (inherit mono-2.4.2)
    (version "2.6.4")
    (name "mono")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://gitlab.winehq.org/mono/mono.git")
                    (commit (string-append "mono-" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "17977w45qh8jmfsl4bhi83si4fxd8s3x8b0pxnwdzjv3bqr54c85"))
              (modules '((guix build utils)
                         (ice-9 string-fun)))
              (snippet prepare-mono-source)
              (patches (search-patches "mono-2.6.4-fixes.patch"))))
    (native-inputs (modify-inputs (package-native-inputs mono-2.4.2)
                     (replace "mono" mono-2.4.2)))))

;; submodule checkouts use git://, which isn't supported by github anymore, so
;; we need to manually provide them instead of being able to use (recursive?
;; #t).  Also try not to think too hard about the fact that some of these
;; submodules in later versions contain binary compiler blobs which mono
;; maintainers presumably used when creating the bootstrap binaries they
;; published.  All fetched and updated over unauthenticated git://.

(define mono-2.11.4-external-repo-specs
  ;; format: ({reponame OR (reponame dir-name)} commit-hash origin-sha256) ...
  ;; if reponame starts with https:// it is treated as the repository url,
  ;; otherwise the name of a repository under https://github.com/mono/
  '(("aspnetwebstack"               "1836deff6a2683b8a5b7dd78f2b591a10b47573e"
     "0vqq45i8k6jylljarr09hqqiwjs8wn0lgjrl6bz72vxqpp0j344k")
    ("cecil"                        "54e0a50464edbc254b39ea3c885ee91ada730705"
     "007szbf5a14q838695lwdp7ap6rwzz3kzllgjfnibzlqipw3x2yk")
    ("entityframework"              "9baca562ee3a747a41870f45e749e4436b6aca26"
     "0l8k04bykbrbk5q2pz8hzh8xy8y4ayz7j97fw0kyk3lrai89v5da")
    ("Newtonsoft.Json"              "471c3e0803a9f40a0acc8aeceb31de6ff93a52c4"
     "0dgngd5hqk6yhlg40kabn6qdnknm32zcx9q6bm2w31csnsk5978s")))

(define (add-external-repos specs)
  (define (reponame->url reponame)
    (if (string-prefix? "https://" reponame)
        reponame
        (string-append "https://github.com/mono/" reponame)))

  (define* (external-repo-gexp reponame commit hash
                               #:key recursive? (patches '()))
    (let ((short-commit (string-take commit 6))
          (reponame (if (pair? reponame) (car reponame)
                        reponame))
          (dir-name (if (pair? reponame) (cadr reponame)
                        reponame)))
      #~(copy-recursively #+(origin
                              (method git-fetch)
                              (uri (git-reference
                                    (url (reponame->url reponame))
                                    (commit commit)
                                    (recursive? recursive?)))
                              (file-name
                               (git-file-name dir-name
                                              short-commit))
                              (sha256 (base32 hash))
                              (patches (map search-patch patches)))
                          #$(string-append "./external/" dir-name))))

  (define (spec->gexp spec)
    (apply external-repo-gexp spec))

  #~(begin
      #+@(map spec->gexp specs)))

(define-public mono-2.11.4
  (package
    (inherit mono-2.6.4)
    (version "2.11.4")
    (name "mono")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://gitlab.winehq.org/mono/mono.git")
                    (commit (string-append "mono-" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "0y2bifi2avbjmfp80hjga2dyqip4b46zkvx6yfr9pa2hhm940rpx"))
              (modules '((guix build utils)
                         (ice-9 string-fun)))
              (snippet #~(begin
                           #$(add-external-repos
                              mono-2.11.4-external-repo-specs)
                           #$prepare-mono-source))
              (patches (search-patches "mono-2.11.4-fixes.patch"))))
    (build-system gnu-build-system)
    (native-inputs (modify-inputs (package-native-inputs mono-2.6.4)
                     (replace "mono" mono-2.6.4)))
    (license (list
              ;; most of mcs/tools, mono/man, most of mcs/class, tests by
              ;; default, mono/eglib, mono/metadata/sgen*,
              ;; mono/arch/*/XXX-codegen.h
              ;; mcs/mcs, mcs/gmcs (dual-licensed GPL)
              ;; samples
              license:x11
              ;; mcs/mcs, mcs/gmcs (dual-licensed X11)
              ;; some of mcs/tools
              license:gpl1+ ;; note: ./mcs/LICENSE.GPL specifies no version
              ;; mono/mono (the mono VM, I think they meant mono/mini)
              license:lgpl2.0+ ;; note: ./mcs/LICENSE.LGPL specifies no version
              ;; mcs/jay
              license:bsd-4
              ;; mcs/class/System.Core/System/TimeZoneInfo.Android.cs
              license:asl2.0))))

(define mono-3.0.12-external-repo-specs
  ;; format: ({reponame OR (reponame dir-name)} commit sha256) ...
  ;; if reponame starts with https:// it is treated as the repository url,
  ;; otherwise the name of a repository under https://github.com/mono/
  '(("aspnetwebstack"               "e77b12e6cc5ed260a98447f609e887337e44e299"
     "0rks344qr4fmp3fs1264d2qkmm348m8d1kjd7z4l94iiirwn1fq1")
    ("cecil"                        "54e0a50464edbc254b39ea3c885ee91ada730705"
     "007szbf5a14q838695lwdp7ap6rwzz3kzllgjfnibzlqipw3x2yk")
    ("entityframework"              "a5faddeca2bee08636f1b7b3af8389bd4119f4cd"
     "0b05pzf6qwdd92pbzym32nfmw8rq36820vdzakq1kykfmddjr9a7")
    (("ikvm-fork" "ikvm")           "10b8312c8024111780ee382688cd4c8754b1f1ac"
     "025wf9gjgfvrq42vgw91ahy3cmzcw094vx783dsp7gjdyd8q09nm")
    ("Lucene.Net"                   "88fb67b07621dfed054d8d75fd50672fb26349df"
     "1rfxqfz7hkp9rg5anvxlv6fna0xi0bnv1y8qbhf8x48l08yjb38k")
    ("Newtonsoft.Json"              "471c3e0803a9f40a0acc8aeceb31de6ff93a52c4"
     "0dgngd5hqk6yhlg40kabn6qdnknm32zcx9q6bm2w31csnsk5978s")
    ("rx"                           "17e8477b2cb8dd018d49a567526fe99fd2897857"
     "0fyyy4jf0mma6kff6fvbvdcs5ra1bz4s063nvjjva9xlnv7sjvh4")))

(define-public mono-3.0
  (package
    (inherit mono-2.11.4)
    (version "3.0.12")
    (name "mono")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://gitlab.winehq.org/mono/mono.git")
                    (commit (string-append "mono-" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "110f3hcfikk6bxbrgjas5dqldci9f24gvm3vdgn4j9j7xhlcx1lj"))
              (modules '((guix build utils)
                         (ice-9 string-fun)))
              (snippet #~(begin
                           #$(add-external-repos
                              mono-3.0.12-external-repo-specs)
                           #$prepare-mono-source))))
    (native-inputs (modify-inputs (package-native-inputs mono-2.11.4)
                     (replace "mono" mono-2.11.4)))
    (license (list
              ;; most of mcs/tools, mono/man, most of mcs/class, tests by
              ;; default, mono/eglib, mono/metadata/sgen*,
              ;; mono/arch/*/XXX-codegen.h
              ;; mcs/mcs, mcs/gmcs (dual-licensed GPL)
              ;; samples
              license:x11
              ;; mcs/mcs, mcs/gmcs (dual-licensed X11)
              ;; some of mcs/tools
              license:gpl1+ ;; note: ./mcs/LICENSE.GPL specifies no version
              ;; mono/mono (the mono VM, I think they meant mono/mini)
              ;; mono/support (note: directory doesn't exist, probably meant
              ;; ./support, but that contains a copy of zlib?)
              license:lgpl2.0+ ;; note: ./mcs/LICENSE.LGPL specifies no version
              ;; mcs/jay
              license:bsd-4
              ;; mcs/class/System.Core/System/TimeZoneInfo.Android.cs
              license:asl2.0
              ;; ./support, contains a copy of zlib
              license:zlib))))

(define mono-3.12.1-external-repo-specs
  ;; format: ({reponame OR (reponame dir-name)} commit sha256) ...
  '(("aspnetwebstack"               "e77b12e6cc5ed260a98447f609e887337e44e299"
     "0rks344qr4fmp3fs1264d2qkmm348m8d1kjd7z4l94iiirwn1fq1")
    ("cecil"                        "33d50b874fd527118bc361d83de3d494e8bb55e1"
     "1p4hl1796ib26ykyf5snl6cj0lx0v7mjh0xqhjw6qdh753nsjyhb")
    ("entityframework"              "a5faddeca2bee08636f1b7b3af8389bd4119f4cd"
     "0b05pzf6qwdd92pbzym32nfmw8rq36820vdzakq1kykfmddjr9a7")
    ("ikdasm"                       "7ded4decb9c39446be634d42a575fda9bc3d945c"
     "0f3mbfizxmvr5njj123w0wn7sz85v5q2mzwijjql8w1095i0916l")
    (("ikvm-fork" "ikvm")           "22534de2098acbcf208f6b06836d122dab799e4b"
     "1ivywy5sc594sl3bs9xrkna1dbhkp7v1mv79n96ydgq6zcs0698l")
    ("Lucene.Net"                   "88fb67b07621dfed054d8d75fd50672fb26349df"
     "1rfxqfz7hkp9rg5anvxlv6fna0xi0bnv1y8qbhf8x48l08yjb38k")
    ("Newtonsoft.Json"              "471c3e0803a9f40a0acc8aeceb31de6ff93a52c4"
     "0dgngd5hqk6yhlg40kabn6qdnknm32zcx9q6bm2w31csnsk5978s")
    ("rx"                           "00c1aadf149334c694d2a5096983a84cf46221b8"
     "0ndam0qrnkb4gj21lapqgcy0mqw7s18viswsjyjyaaa4fgqw8kmq")))

(define-public mono-3.12.1
  (package
    (inherit mono-3.0)
    (version "3.12.1")
    (name "mono")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://gitlab.winehq.org/mono/mono.git")
                    (commit (string-append "mono-" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "01sxrnfch61k8v7av7ccbmy3v37ky8yp8460j6ycnbyfa3305y0f"))
              (modules '((guix build utils)
                         (ice-9 string-fun)))
              (snippet #~(begin
                           #$(add-external-repos
                              mono-3.12.1-external-repo-specs)
                           #$prepare-mono-source))))
    (native-inputs (modify-inputs (package-native-inputs mono-3.0)
                     (replace "mono" mono-3.0)))
    (arguments
     (substitute-keyword-arguments (package-arguments mono-3.0)
       ((#:phases phases #~%standard-phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'set-TZ
              (lambda _
                ;; for some reason a default is only used if this is empty, not
                ;; if it is unset.
                (setenv "TZ" "")))))))))

(define mono-4.9.0-external-repo-specs
  ;; format: ({reponame OR (reponame dir-name)} commit sha256) ...
  '(("aspnetwebstack"               "e77b12e6cc5ed260a98447f609e887337e44e299"
     "0rks344qr4fmp3fs1264d2qkmm348m8d1kjd7z4l94iiirwn1fq1")
    ;; (("reference-assemblies" "binary-reference-assemblies")
    ;;  "6c77197318fe85dfddf75a1b344b9bf8d0007b0b"
    ;;  "11hbs952srjlsiyin76y2llm5rfjkwjc67ya1i3p0pw193zw14jk")
    ;; According to github description this is a "custom" fork of boringssl
    ("boringssl"                    "c06ac6b33d3e7442ad878488b9d1100127eff998"
     "187zpi1rvh9i6jfccwzqq337rxxi1rgny6mjq79r08dlrh0lydzc")
    ("buildtools"                   "9b6ee8686be55a983d886938165b6206cda50772"
     "0sjw3swavcmijynmaxh647qpkjsbgihdr8lhkyzf8dsprhlq4fxd")
    ("cecil"                        "2b39856e80d8513f70bc3241ed05325b0de679ae"
     "0vvax32r6bnhvrcvis83gdrdqcgyxb704hz28g9q0wnay4knqxdm")
    (("cecil" "cecil-legacy")       "33d50b874fd527118bc361d83de3d494e8bb55e1"
     "1p4hl1796ib26ykyf5snl6cj0lx0v7mjh0xqhjw6qdh753nsjyhb")
    ;; ("debian-snapshot"              "9342f8f052f81deaba789f030db23a88b4369724"
    ;;  "")
    ("ikdasm"                       "e4deabf61c11999f200dcea6f6d6b42474cc2131"
     "1frbf70y7n7l72j393avdiwk6153cvfwwpighkf2m46clqmq4han")
    (("ikvm-fork" "ikvm")           "367864ef810859ae3ce652864233b35f2dd5fdbe"
     "0ig99kbma4s0mzb13nzsk1vm200ygfr11q6mzgh6jj46s2fc35px")
    ("Lucene.Net.Light"             "85978b7eb94738f516824341213d5e94060f5284"
     "0d118i52m3a0vfjhfci81a2kc4qvnj23gs02hrvdrfpd1q92fyii")
    ("Newtonsoft.Json"              "471c3e0803a9f40a0acc8aeceb31de6ff93a52c4"
     "0dgngd5hqk6yhlg40kabn6qdnknm32zcx9q6bm2w31csnsk5978s")
    ("nuget-buildtasks"             "04bdab55d8de9edcf628694cfd2001561e8f8e60"
     "1nklxayxkdskg5wlfl44cndzqkl18v561rz03hwx7wbn5w89q775")
    ("nunit-lite"                   "4bc79a6da1f0ee538560b7e4d0caff46d3c86e4f"
     "085fpabjw47rn8hb5zw6wizsg2jrgdbj9rnlar9lrls40wig272q")
    ("rx"                           "b29a4b0fda609e0af33ff54ed13652b6ccf0e05e"
     "1n1jwhmsbkcv2d806immcpzkb72rz04xy98myw355a8w5ah25yiv")))

(define-public mono-4.9.0
  (package
    (inherit mono-3.12.1)
    (version "4.9.0")
    (name "mono")
    (source (origin
              (method git-fetch)
              (uri
               (git-reference
                (url "https://gitlab.winehq.org/mono/mono.git")
                ;; some commit chosen after configure.ac was updated to make
                ;; the version >= 4.9.0
                (commit "5a3736606e6243d2c84d4df2cf35c284214b8cc4")))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "0vqkkqkaqwbii4hdzg0vffyy31fz1kmmsa67jyqwxdsvgpjszih3"))
              (modules '((guix build utils)
                         (ice-9 string-fun)))
              (snippet #~(begin
                           #$(add-external-repos
                              mono-4.9.0-external-repo-specs)
                           #$prepare-mono-source))
              (patches (search-patches
                        ;; Saves us an extra intermediate step
                        "mono-4.9.0-fix-runtimemetadataversion.patch"))))
    (native-inputs (modify-inputs (package-native-inputs mono-3.12.1)
                     (replace "mono" mono-3.12.1)
                     (append tzdata-for-tests)))
    (arguments
     (substitute-keyword-arguments (package-arguments mono-3.12.1)
       ((#:configure-flags _ #f)
        ;; "External Boehm is no longer supported" - I VILL NOT use the
        ;; bundled software!
        #~(list "--with-sgen=yes"
                "--disable-boehm"
                "--with-csc=mcs"))
       ((#:phases phases #~%standard-phases)
        #~(modify-phases #$phases
            (add-before 'configure 'set-TZDIR
              (lambda* (#:key native-inputs inputs #:allow-other-keys)
                (search-input-directory (or native-inputs inputs)
                                        "share/zoneinfo")))
            (add-after 'unpack 'use-old-mono-libraries
              ;; At this point in history mono had not, to my knowledge,
              ;; deigned to grace us with the actual sources to the binaries
              ;; shipped in external/binary-reference-assemblies, so just copy
              ;; the libraries from an older mono for now I guess.
              (lambda _
                (substitute* "mcs/class/reference-assemblies/Makefile"
                  (("\\.\\./\\.\\./\\.\\./external/binary-reference-assemblies/v")
                   (string-append #$(this-package-native-input "mono")
                                  "/lib/mono/")))))
            (add-after 'unpack 'disable-Microsoft.Build.Tasks-tests
              (lambda _
                ;; These fail for unknown reasons
                (substitute* "mcs/class/Microsoft.Build.Tasks/Makefile"
                  (("^include ../../build/library.make" all)
                   (string-append
                    all "\nrun-test-recursive:\n\t@echo skipping tests\n")))))))))
    (license (list
              ;; most of mcs/tools, mono/man, most of mcs/class, tests by
              ;; default, mono/eglib, mono/metadata/sgen*,
              ;; mono/arch/*/XXX-codegen.h
              ;; mcs/mcs, mcs/gmcs (dual-licensed GPL)
              ;; samples
              license:x11
              ;; mcs/mcs, mcs/gmcs (dual-licensed X11)
              ;; some of mcs/tools
              license:gpl1+ ;; note: ./mcs/LICENSE.GPL specifies no version
              ;; mono/mono (the mono VM, I think they meant mono/mini)
              ;; mono/support (note: directory doesn't exist, probably meant
              ;; ./support, but that contains a copy of zlib?)
              license:lgpl2.0+ ;; note: ./mcs/LICENSE.LGPL specifies no version
              ;; mcs/jay, mono/utils/memcheck.h
              license:bsd-4
              ;; mono/utils/bsearch.c, mono/io-layer/wapi_glob.{h,c}
              license:bsd-3
              ;; mono/utils/freebsd-{dwarf,elf_common,elf64,elf32}.h
              license:bsd-2
              ;; mcs/class/System.Core/System/TimeZoneInfo.Android.cs
              ;; mcs/class/RabbitMQ.Client (dual licensed mpl1.1)
              license:asl2.0
              ;; ./support, contains a copy of zlib, incl. ./support/minizip
              license:zlib
              ;; mono/docs/HtmlAgilityPack, mcs/unit24
              license:ms-pl
              ;; mcs/class/I18N/mklist.sh, mono/benchmark/{zipmark,logic}.cs
              ;; mcs/class/{,Compat.}ICSharpCode.SharpZipLib
              license:gpl2+
              ;; mcs/class/RabbitMQ.Client (dual licensed asl2.0)
              license:mpl1.1
              ;; API Documentation
              license:cc-by4.0))))

(define mono-5.0.1-external-repo-specs
  '(("aspnetwebstack"              "e77b12e6cc5ed260a98447f609e887337e44e299"
     "0rks344qr4fmp3fs1264d2qkmm348m8d1kjd7z4l94iiirwn1fq1")
    ;; snippet in the actual package will delete all dlls and exes, so this
    ;; should be rebuilt from scratch.
    (("reference-assemblies" "binary-reference-assemblies")
     "febc100f0313f0dc9d75dd1bcea45e87134b5b55"
     "0lpj911m2lq23r22dpy4i02fy4ykf27dx8fvqpxsxknysj2jl6y4")
    ("bockbuild"                   "512ba41a94bec35ff0c395eb71a180fda23da95c"
     "16m00la8svx8v07sxy4zxbpq0cbq7d3nzy53w8kqml8b18h5dabg")
    ("boringssl"                   "c06ac6b33d3e7442ad878488b9d1100127eff998"
     "187zpi1rvh9i6jfccwzqq337rxxi1rgny6mjq79r08dlrh0lydzc")
    ("buildtools"                  "9b6ee8686be55a983d886938165b6206cda50772"
     "0sjw3swavcmijynmaxh647qpkjsbgihdr8lhkyzf8dsprhlq4fxd")
    ("cecil"                       "7801534de1bfed97c844821c3244e05fc7ffcfb8"
     "0dmfyzkm57n3lbgllx6ffz4g84x1slkib9hb4cfp3nhz852qim7b")
    (("cecil" "cecil-legacy")      "33d50b874fd527118bc361d83de3d494e8bb55e1"
     "1p4hl1796ib26ykyf5snl6cj0lx0v7mjh0xqhjw6qdh753nsjyhb")
    ("corefx"                      "bd96ae5f1485ae8541fe476dfd944efde76bcd9c"
     "0j51lc54dmwa4fzna2vjfj4pcd1lk1s5bp5dfix1aqcncyzivazi")
    ("corert"                      "d87c966d80c1274373ddafe3375bf1730cd430ed"
     "078v5ks7inm2g1hf96x19k42jnv1qhhh7r8jxrfc7jk4v4lgmqyf")
    ("ikdasm"                      "e4deabf61c11999f200dcea6f6d6b42474cc2131"
     "1frbf70y7n7l72j393avdiwk6153cvfwwpighkf2m46clqmq4han")
    (("ikvm-fork" "ikvm")          "367864ef810859ae3ce652864233b35f2dd5fdbe"
     "0ig99kbma4s0mzb13nzsk1vm200ygfr11q6mzgh6jj46s2fc35px")
    ("linker"                      "e4d9784ac37b9ebf4757175c92bc7a3ec9fd867a"
     "0ga7br9lqdsycz22dndkbiwbd0c60ml6nl22xlsnjr7lwdccfjvl")
    ("Lucene.Net.Light"            "85978b7eb94738f516824341213d5e94060f5284"
     "0d118i52m3a0vfjhfci81a2kc4qvnj23gs02hrvdrfpd1q92fyii")
    ("Newtonsoft.Json"             "471c3e0803a9f40a0acc8aeceb31de6ff93a52c4"
     "0dgngd5hqk6yhlg40kabn6qdnknm32zcx9q6bm2w31csnsk5978s")
    (("NuGet.BuildTasks" "nuget-buildtasks")
     "8d307472ea214f2b59636431f771894dbcba7258"
     "1h1frnj0x8k7b29ic4jisch0vlpmsmghjw554pz277f2nxaidljj")
    (("NUnitLite" "nunit-lite")    "690603bea98aae69fca9a65130d88591bc6cabee"
     "1f845ysjzs3yd9gcyww66dnkx484z5fknb8l0xz74sjmxk2mngwc")
    ;; ("roslyn-binaries"          "0d4198b1299bcb019973749da4d47e90f15a1e46"
    ;;  "")
    ("rx"                          "b29a4b0fda609e0af33ff54ed13652b6ccf0e05e"
     "1n1jwhmsbkcv2d806immcpzkb72rz04xy98myw355a8w5ah25yiv")))

(define-public mono-5.0.1
  (package
    (inherit mono-4.9.0)
    (version "5.0.1")
    (name "mono")
    (source (origin
              (method git-fetch)
              (uri
               (git-reference
                (url "https://gitlab.winehq.org/mono/mono.git")
                (commit "mono-5.0.1.1")))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "05z9bddljp8xwsw7qw3f7bic8i202wrc60pjb9fn4igwfz9278n5"))
              (modules '((guix build utils)
                         (ice-9 string-fun)))
              (snippet #~(begin
                           #$(add-external-repos
                              mono-5.0.1-external-repo-specs)
                           #$@prepare-mono-source-0))))
    (native-inputs (modify-inputs (package-native-inputs mono-4.9.0)
                     (replace "mono" mono-4.9.0)
                     (append cmake-minimal)))
    (arguments
     (substitute-keyword-arguments (package-arguments mono-4.9.0)
       ((#:make-flags _ #f)
        ;; Build system is buggy here, it does some weird wildcard expansion
        ;; that assumes there's only at most one file in a directory
        #~(list "V=1" "SKIP_AOT=1"))
       ((#:phases phases #~%standard-phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'disable-roslyn-install
              ;; For some reason there is no predefined way to persuade mono to
              ;; not install the binary blobs it assumes are there.
              (lambda _
                (substitute* "mcs/packages/Makefile"
                  (("^install-local:")
                   (string-append "install-local:
	echo \"Skipping blob install\"

unused0:")))))
            (delete 'use-old-mono-libraries)
            (add-after 'build 'build-reference-assemblies
              (lambda* (#:key make-flags parallel-build? #:allow-other-keys)
                (let ((top (getcwd))
                      ;; parallel-build? needs to be false for mono's build
                      ;; phase, but it should work here.
                      (parallel-build? #t))
                  (with-directory-excursion "external/binary-reference-assemblies"
                    ;; No clue why all these references are missing, just
                    ;; power through I guess.
                    (substitute* (find-files "." "^Makefile$")
                      (("CSC_COMMON_ARGS := " all)
                       (string-append all "-delaysign+ "))
                      (("IBM\\.Data\\.DB2_REFS := " all)
                       (string-append all "System.Xml "))
                      (("Mono\\.Data\\.Sqlite_REFS := " all)
                       (string-append all "System.Xml "))
                      (("System\\.Data\\.DataSetExtensions_REFS := " all)
                       (string-append all "System.Xml "))
                      (("System\\.Data\\.OracleClient_REFS := " all)
                       (string-append all "System.Xml "))
                      (("System\\.IdentityModel_REFS := " all)
                       (string-append all "System.Configuration "))
                      (("System\\.Design_REFS := " all)
                       (string-append all "Accessibility "))
                      (("System\\.Web\\.Extensions\\.Design_REFS := " all)
                       (string-append all "System.Windows.Forms System.Web "))
                      (("System\\.ServiceModel\\.Routing_REFS := " all)
                       (string-append all "System.Xml "))
                      (("System\\.Web\\.Abstractions_REFS := " all)
                       (string-append all "System "))
                      (("System\\.Reactive\\.Windows\\.Forms_REFS := " all)
                       (string-append all "System "))
                      (("System\\.Windows\\.Forms\\.DataVisualization_REFS := " all)
                       (string-append all "Accessibility "))
                      (("Facades/System\\.ServiceModel\\.Primitives_REFS := " all)
                       (string-append all "System.Xml "))
                      (("Facades/System\\.Dynamic\\.Runtime_REFS := " all)
                       (string-append all "System "))
                      (("Facades/System\\.Xml\\.XDocument_REFS := " all)
                       (string-append all "System.Xml "))
                      (("Facades/System\\.Runtime\\.Serialization.Xml_REFS := " all)
                       (string-append all "System.Xml ")))
                    (apply invoke "make"
                           `(,@(if parallel-build?
                                   `("-j" ,(number->string
                                            (parallel-job-count)))
                                   '())
                             ,(string-append "CSC=MONO_PATH="
                                             top "/mcs/class/lib/build"
                                             " "
                                             top "/runtime/mono-wrapper"
                                             " "
                                             top "/mcs/class/lib/build/mcs.exe")
                             ,@make-flags))))))))))))
