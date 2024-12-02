sass = find_program('sass')

scss_deps = files(
    'main.scss',
    'context.scss',
)

scss = custom_target(
    'scss',
    input: 'main.scss',
    output: 'fgeronimo.css',
    command: [
        sass,
        '@INPUT@',
        '@OUTPUT@',
    ],
    depend_files: scss_deps,
)