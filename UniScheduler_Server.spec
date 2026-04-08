# -*- mode: python ; coding: utf-8 -*-

import sqladmin, os
sqladmin_dir = os.path.dirname(sqladmin.__file__)

a = Analysis(
    ['run_server.py'],
    pathex=['.'],
    binaries=[],
    datas=[
        (os.path.join(sqladmin_dir, 'statics'), 'sqladmin/statics'),
        (os.path.join(sqladmin_dir, 'templates'), 'sqladmin/templates'),
        # FIX 1: Removed 'backend/.env' — file does not exist in repo (only .env.example).
        # The app resolves its DB path dynamically in database/config.py without needing .env.
        # If you want to bundle a default .env, run: cp backend/.env.example backend/.env
        # and uncomment the line below before building.
        # ('backend/.env', 'backend'),
    ],
    hiddenimports=[
        # --- Uvicorn internals ---
        'uvicorn.logging',
        'uvicorn.loops',
        'uvicorn.loops.auto',
        'uvicorn.protocols',
        'uvicorn.protocols.http',
        'uvicorn.protocols.http.auto',
        'uvicorn.protocols.websockets',
        'uvicorn.protocols.websockets.auto',
        'uvicorn.lifespan',
        'uvicorn.lifespan.on',

        # FIX 2: Added missing FastAPI / Starlette runtime dependencies
        'anyio',
        'anyio._backends._asyncio',
        'anyio._backends._trio',
        'email_validator',
        'multipart',
        'starlette.routing',
        'starlette.middleware',

        # --- API entry points ---
        'backend.api.main',
        'backend.api.routers.timetable_router',
        'backend.api.routers.session_router',
        'backend.api.routers.timetable_view',

        # FIX 3: Expanded admin routers — each module must be listed individually.
        # 'backend.api.routers.admin' alone does NOT pull in the sub-modules.
        'backend.api.routers.admin.branch_router',
        'backend.api.routers.admin.classroom_router',
        'backend.api.routers.admin.enrollment_router',
        'backend.api.routers.admin.group_router',
        'backend.api.routers.admin.group_student_router',
        'backend.api.routers.admin.slot_router',
        'backend.api.routers.admin.student_router',
        'backend.api.routers.admin.subject_router',
        'backend.api.routers.admin.teacher_availability_router',
        'backend.api.routers.admin.teacher_router',

        # FIX 4: Database models — SQLAlchemy loads these dynamically; must be explicit.
        'backend.database.config',
        'backend.database.session',
        'backend.database.models',
        'backend.database.models.branch',
        'backend.database.models.classroom',
        'backend.database.models.enrollment',
        'backend.database.models.group',
        'backend.database.models.group_student',
        'backend.database.models.session',
        'backend.database.models.session_entities',
        'backend.database.models.session_slot',
        'backend.database.models.slot',
        'backend.database.models.student',
        'backend.database.models.subject',
        'backend.database.models.sync_revision',
        'backend.database.models.teacher',
        'backend.database.models.teacher_availability',
        'backend.database.models.timetable_conflict',
        'backend.database.models.timetable_conflict_type',
        'backend.database.models.timetable_entry',
        'backend.database.models.timetable_version',

        # FIX 4 (cont): SQLAlchemy SQLite dialect — required for SQLite to work when frozen.
        'sqlalchemy.dialects.sqlite',

        # --- Scheduler engine ---
        'backend.scheduler_engine',
        'backend.scheduler_engine.entities',
        'backend.scheduler_engine.initialization',
        'backend.scheduler_engine.constraints',
        'backend.scheduler_engine.objectives',
        'backend.scheduler_engine.nsga2',
        'backend.scheduler_engine.generator',

        # --- Services, bridge, admin ---
        'backend.admin',
        'backend.bridge.runner',
        'backend.bridge.data_loader',
        'backend.api.services.bootstrap_service',
        'backend.api.services.timetable_service',
        'backend.api.services.timetable_saver',
        'backend.api.services.timetable_queries',
        'backend.api.services.session_copy_service',
        'backend.api.services.session_entities_service',
        'backend.api.services.student_import_service',
        'backend.api.utils.excel_exporter',
        'backend.api.utils.timetable_utils',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)
pyz = PYZ(a.pure)
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='UniScheduler_Server',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    # FIX 5: Changed console=False → console=True.
    # The server is a background process; with console=False any startup error is
    # completely silent. Set to True so server logs/errors are visible.
    # If you want a truly silent background service, redirect stdout in run_server.py instead.
    console=True,
    icon=None,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='UniScheduler_Server',
)
