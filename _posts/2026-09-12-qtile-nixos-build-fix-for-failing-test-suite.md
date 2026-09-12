---
layout: post
title: Qtile NixOS build fix for failing test suite
date: 2026-09-12
description: How to work around failing Qtile pytest checks during a NixOS rebuild.
tags: linux nixos qtile
categories: Linux NixOS
---

I was updating my NixOS machine, and right at the end, the rebuild failed. Some packages have been problematic for me in the past, such as `oh-my-pi`, but when I checked the logs it was not one of the usual suspects. Suprisingly, the failure was coming from `qtile` (the Python-based tiling window manager).

The logs included the following lines:

```text
       > -- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
       > =========================== short test summary info ============================
       > FAILED test/test_manager.py::test_reload_config[1-x11] - AssertionError: assert 'dd' in []
       > FAILED test/shell_scripts/test_repl_server.py::test_repl_server_executes_code - ConnectionResetError: Connection lost
       > ERROR test/test_dgroups.py::test_dgroup_spawn_in_group[1-x11-DGroupsSpawnConfig] - AssertionError: Error launching qtile
```

What worked in the end for me was to skip the Qtile test suite for this package build. You can do that by adding the following to your `configuration.nix`:

```nix
services.xserver.windowManager.qtile = {
  enable = true;
  package = pkgs.python3.pkgs.qtile.overrideAttrs (_: {
    doCheck = false;
    doInstallCheck = false;
    dontUsePytestCheck = true;
  });
};
```

Make sure any overlays you use are not overriding or bypassing this package setting. To check that the option is being applied, run:

```sh
nix eval --impure --json --expr \
  '(let c = (builtins.getFlake "/etc/nixos").nixosConfigurations.nixos.config; in c.services.xserver.windowManager.qtile.package.doCheck == false)'
```

The result should be `true`.

Before rebuilding the whole system, you can test-build Qtile directly:

```sh
nix build --impure --no-link \
  --expr '(builtins.getFlake "/etc/nixos").nixosConfigurations.nixos.config.services.xserver.windowManager.qtile.finalPackage'
```

There is an issue on GitHub tracking the problem: [NixOS/nixpkgs#559128](https://github.com/NixOS/nixpkgs/issues/559128). Once the issue is resolved upstream, this workaround can be removed from your configuration.

## Why disable the tests? Seems a bit drastic

"Untested code is garbage code." Disabling tests was not my first choice, so I tried a few narrower workarounds first.

The error log included `Connection lost`, and my internet connection is not always reliable, so I initially tried rerunning the build. After a couple of attempts, it became clear that this was not just a network issue.

Next, I tried disabling only the failing tests. I was able to to figure out how to do that, but doing so only uncovered more failures. At that point, disabling 100+ tests would have made my configuration messy and seemed to defeat the purpose of keeping the checks enabled.

In the end, disabling the pytest checks altogether was what allowed the package to build successfully. Hopefully this is fixed upstream, either by adjusting the failing tests or by moving to a smaller post-installation test suite.

## Extra technical details

The Qtile NixOS module consumes `services.xserver.windowManager.qtile.package`, not necessarily the package selected by a separate `python313Packages` overlay. The module also calls `.override` on that package to add extra packages, so the override must preserve that interface.

Qtile uses `buildPythonPackage` with `pytestCheckHook`. In this nixpkgs version, setting only the final `doCheck` attribute with `overrideAttrs` leaves Python install checks and the pytest hook active. The package override disables all of those checks while retaining the module-compatible `.override` method:

```nix
# configuration.nix
services.xserver.windowManager.qtile = {
  enable = true;
  package = pkgs.python3.pkgs.qtile.overrideAttrs (_: {
    doCheck = false;
    doInstallCheck = false;
    dontUsePytestCheck = true;
  });
};
```

- `doCheck = false` is the required setting on the exact package consumed by Qtile.
- `doInstallCheck = false` disables Python's separate install-check phase.
- `dontUsePytestCheck = true` prevents `pytestCheckHook` from adding `pytestCheckPhase`.

## Verification

```sh
nix eval --impure --json --expr \
  '(let c = (builtins.getFlake "/etc/nixos").nixosConfigurations.nixos.config; in {
    package = c.services.xserver.windowManager.qtile.package.name;
    doCheck = c.services.xserver.windowManager.qtile.package.doCheck;
    doInstallCheck = c.services.xserver.windowManager.qtile.package.doInstallCheck;
    dontUsePytestCheck = c.services.xserver.windowManager.qtile.package.dontUsePytestCheck;
  })'
```

The expected values are `python3.13-qtile-0.36.0`, `false`, `false`, and `true`. A build of the service's `finalPackage` should complete successfully without a `pytestCheckPhase` in the build log.

## Original failure log

```text
       Reason: builder failed with exit code 1.
       Output paths:
         /nix/store/7lfmh6jjxd36wvv31cdyii61m7jizp69-python3.13-qtile-0.36.0-dist
         /nix/store/j8frdrqpw6yi839sa8l6f30y4wkcr3ip-python3.13-qtile-0.36.0
       Last 25 log lines:
       > test/layouts/test_screensplit.py: 4 warnings
       > test/layouts/test_slice.py: 8 warnings
       > test/layouts/test_spiral.py: 11 warnings
       > test/widgets/test_systray.py: 3 warnings
       > test/widgets/test_tasklist.py: 13 warnings
       > test/widgets/test_textbox.py: 5 warnings
       > test/widgets/test_vertical_clock.py: 8 warnings
       > test/widgets/test_widget_init_configure.py: 13 warnings
       >   /nix/store/h3l4z7p6wny3phbckwwhy1i2g52pdnj4-python3-3.13.15/lib/python3.13/multiprocessing/popen_fork.py:73: DeprecationWarning: This process (pid=1141) is multi-threaded, use of fork() may lead to deadlocks in the child.
       >     self.pid = os.fork()
       >
       > test/layouts/test_common.py: 29 warnings
       > test/layouts/test_floating.py: 2 warnings
       > test/layouts/test_matrix.py: 6 warnings
       > test/layouts/test_max.py: 6 warnings
       > test/widgets/test_widget_init_configure.py: 36 warnings
       >   /nix/store/h3l4z7p6wny3phbckwwhy1i2g52pdnj4-python3-3.13.15/lib/python3.13/multiprocessing/popen_fork.py:73: DeprecationWarning: This process (pid=1147) is multi-threaded, use of fork() may lead to deadlocks in the child.
       >     self.pid = os.fork()
       >
       > -- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
       > =========================== short test summary info ============================
       > FAILED test/test_manager.py::test_reload_config[1-x11] - AssertionError: assert 'dd' in []
       > FAILED test/shell_scripts/test_repl_server.py::test_repl_server_executes_code - ConnectionResetError: Connection lost
       > ERROR test/test_dgroups.py::test_dgroup_spawn_in_group[1-x11-DGroupsSpawnConfig] - AssertionError: Error launching qtile
       > = 2 failed, 1369 passed, 27 skipped, 891 warnings, 1 error, 10 rerun in 1611.61s (0:26:51) =
       For full logs, run:
         nix log /nix/store/cq8544x0b1350hpwshg5ryhkiiz3dfpi-python3.13-qtile-0.36.0.drv
error: Cannot build '/nix/store/3vxsdpmax595b5k4fbx9jcka6hsn2l32-desktops.drv'.
```
