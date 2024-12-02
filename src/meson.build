source_files = [
    'App.vala',
    'FileExplorer.vala',
    'ActionHistory.vala',
    'EventListener.vala',
    
    'Utils/FileActions.vala',
    'Utils/FileObject.vala',
    'Utils/Thumbnail.vala',
    'Utils/ThumbnailCache.vala',
    'Utils/Layer.vala',
    'Utils/Daemon.vala',
    'Utils/FileMonitor.vala',
]

executable(
    project_name,
    project_resources,
    sources: source_files,
    vala_args: ['--gresourcesdir=data/'],
    
    dependencies: [
        dependency('gtk4'),
        dependency('gtk4-layer-shell-0'),
        dependency('libnm'),
        dependency('gio-unix-2.0'),
        dependency('libadwaita-1'),
    ],
    link_args: ['-lm'],
    install: true,
)