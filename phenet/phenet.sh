#!/bin/bash

run_script=$0

run_args=()

dry=false
overwrite=false
config_files=()
use_cauchy=false
opts_file_loaded=false
use_qsub=false
use_qsub_specified=false

while [[ $# -gt 0 ]]; do
  arg=$1
  shift
  run_args+=("$arg")
  case $arg in
    -f|--file)
      file=$1
      shift
      opts_file_loaded=true
      if [ -z "$file" ]; then
        echo "Option -f or --file needs to be followed by a file name"
        exit 1
      fi
      path=$(realpath -s "$file")
      if [ ! -f "$path" ]; then
        echo "File $path does not exist."
        exit 2
      fi
      run_args+=("$path")
      echo "Now reading file $path"
      while read -r key value || [ "$key" ]; do
        echo "$key $value"
        case $key in
          \#*|"")
            # Comment or empty line - ignore
            ;;
          action)
            case $value in
              train)
                action=train
                ;;
              classify)
                action=classify
                ;;
              "")
                echo "Need to provide value for action (train or classify)"
                exit 5
                ;;
              *)
                echo "Unknown action $value. Use train or classify"
                exit 5
            esac
            ;;
          py_script)
            py_script=$value
            ;;
          config_file)
            config_files+=("$value")
            ;;
          use_cauchy)
            case $value in
              true)
                use_cauchy=true
                ;;
              false)
                use_cauchy=false
                ;;
              *)
                echo "Unknown value for use_cauchy. Use true or false."
                exit 12
                ;;
            esac
            ;;
          use_qsub)
            case $value in
              true)
                use_qsub=true
                ;;
              false)
                use_qsub=false
                ;;
              *)
                echo "Unknown value for use_qsub. Use true or false."
                exit 12
                ;;
            esac
            use_qsub_specified=true
            ;;
          num_chunks)
            num_chunks=$value
            ;;
          var_id_file)
            var_id_file=$value
            ;;
          output_file)
            output_file=$value
            ;;
          output_file_prefix)
            output_file_prefix=$value
            ;;
          theano_compiledirs_prefix)
            theano_compiledirs_prefix=$value
            ;;
          *)
            echo "Unknown key $key"
            exit 7
        esac
      done < "$path"
      echo "Done reading file $path."
      ;;
    --dry)
      dry=true
      ;;
    --overwrite)
      overwrite=true
      ;;
    -*)
      echo "Unknown option $arg"
      exit 3
      ;;
    *)
      echo "Unused input $arg."
      exit 4
      ;;
  esac
done

if [ $opts_file_loaded = false ]; then
  echo "Need to specify at least on options file using -f."
  exit 22
fi

function assert_is_file() {
  if [ ! -e "$1" ]; then echo "File $1 does not exist"; exit 9; fi
  if [ ! -f "$1" ]; then echo "File $1 is not a regular file"; exit 10; fi
}

if [ -z "$action" ]; then echo "No action provided"; exit 6; fi
if [ -z "$py_script" ]; then echo "No py_script provided"; exit 8; fi
assert_is_file "$py_script"

if [ ${#config_files[@]} -eq 0 ]; then echo "No config_file provided"; exit 11; fi

for config_file in "${config_files[@]}"; do
  if [ -z "$config_file" ]; then echo "Empty value for config_file"; exit 12; fi
  assert_is_file "$config_file"
done

echo "action $action"

case $action in
  train)
    if [ -z "$var_id_file" ]; then echo "No var_id_file provided"; exit 8; fi
    assert_is_file "$var_id_file"

    if [ -z "$output_file" ]; then echo "No output_file provided"; exit 8; fi

    if [ "$overwrite" = false ]; then
      if [ -e "$output_file" ]; then
        echo "File $output_file already exists. Specify --overwrite if you want to overwrite it"
        exit 14
      fi
    fi

    if [ $use_qsub = true ]; then
      echo "Using qsub is not supported for training."
      exit 23
    fi

    cmd_parts=("python" "$py_script" "$action")
    for config_file in "${config_files[@]}"; do
      cmd_parts+=("--config-file" "$config_file")
    done
    cmd_parts+=("--pymc3")
    cmd_parts+=("--debug-level" "3")
    cmd_parts+=("--delim" ";")
    cmd_parts+=("--var-id-file" "$var_id_file")
    cmd_parts+=("--output-file" "$output_file")
    if [ $dry = true ]; then
      echo "This would run:"
      echo "${cmd_parts[@]}"
    else
      # This is required to use dotkits inside scripts
      source /broad/software/scripts/useuse

      # Use your dotkit
      reuse Python-3.9
      reuse Anaconda3

      source activate model

      # Run!
      set -x
      "${cmd_parts[@]}"
      set +x

    fi
    ;;
  classify)
    if [ $use_qsub_specified = false ]; then
      echo "Need to supply use_qsub option for classification."
    fi
    cmd_parts=("python" "$py_script" "$action")
    for config_file in "${config_files[@]}"; do
      cmd_parts+=("--config-file" "$config_file")
    done
    cmd_parts+=("--pymc3")
    cmd_parts+=("--debug-level" "3")
    if [ $use_cauchy = true ]; then
      cmd_parts+=("--use-cauchy")
    fi
    if [ -n "$var_id_file" ]; then
      assert_is_file "$var_id_file"
      cmd_parts+=("--var-id-file" "$var_id_file")
    fi
    cmd_parts+=("--delim" ";")
    if [ $use_qsub = true ]; then
      if [ -z "$num_chunks" ]; then echo "No num_chunks provided"; exit 8; fi
      if [ "$num_chunks" -le 0 ]; then echo "num_chunks needs to be larger than 0"; exit 13; fi
      if [ -z "$output_file_prefix" ]; then echo "No num_output_file_prefix provided"; exit 8; fi
      if [ -z "$theano_compiledirs_prefix" ]; then echo "No theano_compiledirs_prefix provided"; exit 8; fi

      echo "run_script=$run_script"
      echo "num_chunks=$num_chunks"
      echo "SGE_TASK_ID=$SGE_TASK_ID"

      if [ -n "$JOB_ID" ]; then job_id="$JOB_ID"; else job_id="<job_id>"; fi
      if [ -n "$SGE_TASK_ID" ]; then task_id="$SGE_TASK_ID"; else task_id="<task_id>"; fi

      cmd_parts+=("--num-chunks" "$num_chunks")
      cmd_parts+=("--chunk" "$task_id")
      cmd_parts+=("--output-file" "$output_file_prefix.$job_id.$task_id")

      if [ $dry =  true ]; then
        echo "This would run:"
        echo "${cmd_parts[@]}"
      else

        # This is required to use dotkits inside scripts
        source /broad/software/scripts/useuse

        if [[ $SGE_TASK_ID ]]; then

          reuse Python-3.9
          reuse Anaconda3

          source activate model

          export THEANO_FLAGS="compiledir=$theano_compiledirs_prefix.$SGE_TASK_ID"

          # Run!
          set -x
          "${cmd_parts[@]}"
          set +x

        else
          use UGER
          set -x
          qsub -N phenet -l h_vmem=4G -l h_rt=4:00:00 -cwd -t 1-$num_chunks "$run_script" "${run_args[@]}"
          set +x
        fi
      fi
    else
      cmd_parts+=("--output-file" "$output_file")
      if [ $dry = true ]; then
        echo "This would run:"
        echo "${cmd_parts[@]}"
      else
        # This is required to use dotkits inside scripts
        source /broad/software/scripts/useuse

        # Use your dotkit
        reuse Python-3.9
        reuse Anaconda3

        source activate model

        # Run!
        set -x
        "${cmd_parts[@]}"
        set +x

      fi
      echo yo
    fi
    ;;
  *)
    echo "Unknown action $action."
    ;;
esac

echo "Done!"