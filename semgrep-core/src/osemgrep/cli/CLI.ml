(*
   Library defining the semgrep command-line interface.

   This module determines the subcommand invoked on the command line
   and has another module handle it as if it were an independent command.
   We don't use Cmdliner to dispatch subcommands because it's a too
   complicated and we never show a help page for the whole command anyway
   since we fall back to the 'scan' subcommand if none is given.
*)

(* TOPORT:
   def maybe_set_git_safe_directories() -> None:
       """
       Configure Git to be willing to run in any directory when we're in Docker.

       In docker, every path is trusted:
       - the user explicitly mounts their trusted code directory
       - r2c provides every other path

       More info:
       - https://github.blog/2022-04-12-git-security-vulnerability-announced/
       - https://github.com/actions/checkout/issues/766
       """
       env = get_state().env
       if not env.in_docker:
           return

       try:
           # "*" is used over Path.cwd() in case the user targets an absolute path instead of setting --workdir
           git_check_output(["git", "config", "--global", "--add", "safe.directory", "*"])
       except Exception as e:
           logger.info(
               f"Semgrep failed to set the safe.directory Git config option. Git commands might fail: {e}"
           )
*)

(* This is used to determine if we should fall back to assuming 'scan'. *)
let known_subcommands =
  [ "ci"; "login"; "logout"; "lsp"; "publish"; "scan"; "shouldafound" ]

(* Exit with a code that a proper semgrep implementation would never return.
   Uncaught OCaml exception result in exit code 2.
   This is to ensure that the tests that expect error status 2 fail. *)
let missing_subcommand () =
  Printf.eprintf "This semgrep subcommand is not implemented\n%!";
  Exit_code.not_implemented_in_osemgrep

(* python: the help message was automatically generated by Click
 * based on the docstring and the subcommands. In OCaml we generate
 * it manually.
 *)
let main_help_msg =
  {|Usage: semgrep [OPTIONS] COMMAND [ARGS]...

  To get started quickly, run `semgrep scan --config auto`

  Run `semgrep SUBCOMMAND --help` for more information on each subcommand

  If no subcommand is passed, will run `scan` subcommand by default

Options:
  -h, --help  Show this message and exit.

Commands:
  ci            The recommended way to run semgrep in CI
  login         Obtain and save credentials for semgrep.dev
  logout        Remove locally stored credentials to semgrep.dev
  lsp           [EXPERIMENTAL] Start the Semgrep LSP server
  publish       Upload rule to semgrep.dev
  scan          Run semgrep rules on files
  shouldafound  Report a false negative in this project.
|}

let default_subcommand = "scan"

let dispatch_subcommand argv =
  match Array.to_list argv with
  | [] -> assert false
  | [ _; ("-h" | "--help") ] ->
      print_string main_help_msg;
      Exit_code.ok
  | argv0 :: args -> (
      let subcmd, subcmd_args =
        match args with
        | [] -> (default_subcommand, [])
        | arg1 :: other_args ->
            if List.mem arg1 known_subcommands then (arg1, other_args)
            else
              (* No valid subcommand was found.
                 Assume the 'scan' subcommand was omitted and insert it. *)
              (default_subcommand, arg1 :: other_args)
      in
      let subcmd_argv =
        let subcmd_argv0 = argv0 ^ "-" ^ subcmd in
        subcmd_argv0 :: subcmd_args |> Array.of_list
      in
      (* coupling: with known_subcommands above *)
      match subcmd with
      | "ci" -> missing_subcommand ()
      | "login" -> missing_subcommand ()
      | "logout" -> missing_subcommand ()
      | "lsp" -> missing_subcommand ()
      | "publish" -> missing_subcommand ()
      | "scan" -> Semgrep_scan.main subcmd_argv
      | "shouldafound" -> missing_subcommand ()
      (* TOPORT: cli.add_command(install_deep_semgrep) *)
      | _else_ -> (* should have defaulted to 'scan' above *) assert false)

let main argv =
  Printexc.record_backtrace true;

  (* TOPORT:
      state = get_state()
      state.terminal.init_for_cli()
      commands: Dict[str, click.Command] = ctx.command.commands  # type: ignore
      subcommand: str = (
          ctx.invoked_subcommand if ctx.invoked_subcommand in commands else "unset"
      )
      state.app_session.authenticate()
      state.app_session.user_agent.tags.add(f"command/{subcommand}")
      state.metrics.add_feature("subcommand", subcommand)
      maybe_set_git_safe_directories()
  *)
  dispatch_subcommand argv