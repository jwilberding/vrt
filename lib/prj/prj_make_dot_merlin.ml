open Core.Std
open Core_extended.Std
open Async.Std

exception Dot_merlin_write_error

let gather_dirs prefix dirs =
  Vrt_common.Dirs.gather_all_dirs dirs
  >>| fun gathered_dirs ->
  Ok (List.fold ~init:"" ~f:(fun acc dir ->
      acc ^ prefix ^ " " ^ dir ^ "\n") gathered_dirs)

let package_list active_libs =
  (List.fold ~init:"PKG " ~f:(fun acc el -> acc ^ " " ^ el) active_libs) ^ "\n"

let write root contents =
  let path = Filename.implode [root; ".merlin"] in
  try
    Writer.save path ~contents
    >>| fun _ ->
    Ok ()
  with exn ->
    return @@ Result.Error Dot_merlin_write_error

let do_dot_merlin ~active_libs ~source_dirs ~build_dirs ~root_file =
  let banner = "## File generated by `vrt prj make-dot-merlin`, manual changes will be overwritten \n" in
  Prj_project_root.find ~dominating:root_file ()
  >>=? fun project_root ->
  gather_dirs "B" build_dirs
  >>=? fun bdirs ->
  gather_dirs "S" source_dirs
  >>=? fun sdirs ->
  write project_root (banner ^ "\n\n"
                      ^ (package_list active_libs)
                      ^ "\n\n"
                      ^ bdirs
                      ^ "\n\n"
                      ^ sdirs)

let spec =
  let open Command.Spec in
  empty
  +> flag ~aliases:["-l"] "--lib" (listed string)
    ~doc:"lib A library name (package) to include"
  +> flag ~aliases:["-s"] "--source-dir" (listed string)
    ~doc:"source-dir A source directory to include"
  +> flag ~aliases:["-b"] "--build-dir" (listed string)
    ~doc:"build-dir A build directory to include"
  +> flag "--root-file" (optional_with_default "Makefile" string)
    ~doc:"root-file The file that identifies the project root. Probably 'Makefile' or 'Vagrantfile'"

let name = "make-dot-merlin"

let command =
  Command.async_basic
    ~summary:"Generates a valid `.merlin` file in the root of the project directory"
    spec
    (fun active_libs source_dirs build_dirs root_file () ->
       Vrt_common.Cmd.result_guard
         (fun _ ->
            do_dot_merlin
              ~active_libs
              ~source_dirs
              ~build_dirs
              ~root_file))

let desc = (name, command)
