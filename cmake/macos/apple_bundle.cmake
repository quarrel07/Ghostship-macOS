# macOS .app bundle assembly for Ghostship.
#
# Builds "Ghostship.app" directly from the normal build (MACOSX_BUNDLE): compiles the Liquid Glass app
# icon from the Icon Composer package, bundles the runtime resources, relinks non-system dylibs (incl.
# SDL3 for the sdl2-compat shim) into Contents/Frameworks, and ad-hoc codesigns the result so it
# launches without "damaged app" warnings.
#
# Runtime layout (libultraship):
#   * GetAppBundlePath()    -> <App>.app/Contents/Resources  (read-only: ghostship.o2r, assets/, gamecontrollerdb.txt)
#   * GetAppDirectoryPath() -> SHIP_HOME (~/Library/Application Support/com.ghostship):
#                              sm64.o2r extracted from the user's ROM on first run, config/saves/logs/mods

set(MACOS_DIR ${CMAKE_SOURCE_DIR}/cmake/macos)
set(ENTITLEMENTS_FILE ${MACOS_DIR}/entitlements.plist)

option(GHOSTSHIP_BUNDLE_DEPS "Relink and bundle dylibs into the .app so it is portable" ON)

# ---------------------------------------------------------------------------
# Liquid Glass app icon (Icon Composer .icon -> Assets.car + icns fallback via actool)
# ---------------------------------------------------------------------------
set(ICON_SOURCE ${CMAKE_SOURCE_DIR}/macosx/GhostshipIcon.icon)
set(ICON_COMPILE_DIR ${CMAKE_BINARY_DIR}/AppIconAssets)
set(ASSETS_CAR ${ICON_COMPILE_DIR}/Assets.car)
set(ICNS_FALLBACK ${ICON_COMPILE_DIR}/GhostshipIcon.icns)
# actool requires a deployment target value; CMAKE_OSX_DEPLOYMENT_TARGET is unset for this project, so
# fall back to 11.0 (the value is a non-factor for the compiled Liquid Glass catalog, but the flag must
# carry an argument or actool aborts with "Multiple validation errors").
set(ICON_DEPLOYMENT_TARGET "${CMAKE_OSX_DEPLOYMENT_TARGET}")
if (NOT ICON_DEPLOYMENT_TARGET)
    set(ICON_DEPLOYMENT_TARGET "11.0")
endif()
add_custom_command(
    OUTPUT ${ASSETS_CAR} ${ICNS_FALLBACK}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${ICON_COMPILE_DIR}
    COMMAND xcrun actool ${ICON_SOURCE}
            --compile ${ICON_COMPILE_DIR}
            --app-icon GhostshipIcon
            --output-partial-info-plist ${ICON_COMPILE_DIR}/icon-partial.plist
            --platform macosx --target-device mac
            --minimum-deployment-target ${ICON_DEPLOYMENT_TARGET}
            --errors --warnings
    DEPENDS ${ICON_SOURCE}/icon.json
    COMMENT "Compiling Liquid Glass app icon (Icon Composer) with actool"
)
add_custom_target(ghostshipAppIcon DEPENDS ${ASSETS_CAR} ${ICNS_FALLBACK})
add_dependencies(Ghostship ghostshipAppIcon)
set_source_files_properties(${ASSETS_CAR} ${ICNS_FALLBACK} PROPERTIES
    GENERATED TRUE MACOSX_PACKAGE_LOCATION "Resources")
target_sources(Ghostship PRIVATE ${ASSETS_CAR} ${ICNS_FALLBACK})

# ---------------------------------------------------------------------------
# Bundle metadata. OUTPUT_NAME "Ghostship" -> "Ghostship.app" with Contents/MacOS/Ghostship
# (matches CFBundleExecutable in the configured Info.plist).
# ---------------------------------------------------------------------------
set_target_properties(Ghostship PROPERTIES
    OUTPUT_NAME "Ghostship"
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_SOURCE_DIR}/Info.plist
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "-"
    XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS ${ENTITLEMENTS_FILE}
)

# NB: add_dependencies(Ghostship GeneratePortO2R) is added from the root CMakeLists, because
# GeneratePortO2R is defined there (after this file is included).

# ---------------------------------------------------------------------------
# Copy runtime resources into Contents/Resources after the app links
# ---------------------------------------------------------------------------
set(RES_DIR "$<TARGET_BUNDLE_DIR:Ghostship>/Contents/Resources")
add_custom_command(TARGET Ghostship POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "${RES_DIR}"
    # Copy the configured Info.plist in explicitly (keeps the bundle's plist in sync regardless of how
    # MACOSX_BUNDLE emits it).
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/Info.plist" "$<TARGET_BUNDLE_DIR:Ghostship>/Contents/Info.plist"
    COMMAND bash -c "for p in '${CMAKE_BINARY_DIR}/ghostship.o2r' '${CMAKE_SOURCE_DIR}/ghostship.o2r'; do if [ -f \"$p\" ]; then cp \"$p\" '${RES_DIR}/ghostship.o2r'; break; fi; done; [ -f '${RES_DIR}/ghostship.o2r' ] || echo 'note: ghostship.o2r not found - build the GeneratePortO2R target, then rebuild'"
    COMMAND bash -c "[ -f '${CMAKE_BINARY_DIR}/gamecontrollerdb.txt' ] && cp '${CMAKE_BINARY_DIR}/gamecontrollerdb.txt' '${RES_DIR}/gamecontrollerdb.txt' || true"
    # The first-run ROM extractor needs the asset definitions at GetAppBundlePath()/assets
    # (RunExtract checks Contents/Resources/assets). Mirror upstream's Linux install of assets/.
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_SOURCE_DIR}/assets" "${RES_DIR}/assets"
    # Upstream POST_BUILD steps stage dev-run copies (.tcc scripting runtime, config.yml, assets/) next
    # to the binary in Contents/MacOS/. That pollutes the executable dir and breaks codesign (a folder /
    # static .a in MacOS/ isn't signable), and the runtime actually looks for them under Contents/Resources
    # (GetAppBundlePath()). Relocate .tcc + config.yml into Resources and drop the duplicate assets/.
    COMMAND bash -c "MACOS='$<TARGET_BUNDLE_DIR:Ghostship>/Contents/MacOS'; RES='${RES_DIR}'; if [ -d \"$MACOS/.tcc\" ]; then rm -rf \"$RES/.tcc\"; mv \"$MACOS/.tcc\" \"$RES/.tcc\"; fi; if [ -f \"$MACOS/config.yml\" ]; then mv -f \"$MACOS/config.yml\" \"$RES/config.yml\"; fi; rm -rf \"$MACOS/assets\""
    COMMENT "Bundling Ghostship resources into the .app"
    VERBATIM
)

# ---------------------------------------------------------------------------
# Relink dylibs into Contents/Frameworks (portable .app) + SDL3, then codesign
# ---------------------------------------------------------------------------
if (GHOSTSHIP_BUNDLE_DEPS)
    add_custom_command(TARGET Ghostship POST_BUILD
        COMMAND ${CMAKE_COMMAND}
            -DAPP_BUNDLE=$<TARGET_BUNDLE_DIR:Ghostship>
            "-DEXECUTABLE_NAME=Ghostship"
            -P ${MACOS_DIR}/fixup_bundle.cmake
        COMMAND bash -c "install_name_tool -add_rpath '@executable_path/../Frameworks/' '$<TARGET_BUNDLE_DIR:Ghostship>/Contents/MacOS/Ghostship' 2>/dev/null || true"
        # Homebrew's sdl2 is sdl2-compat, a shim that dlopen()s libSDL3.dylib from @loader_path at
        # runtime; fixup_bundle can't follow a dlopen, so copy SDL3 in next to the bundled libSDL2.
        COMMAND bash -c "SDL3_LIB=$(brew --prefix sdl3 2>/dev/null)/lib/libSDL3.0.dylib; if [ -f \"$SDL3_LIB\" ]; then cp \"$SDL3_LIB\" '$<TARGET_BUNDLE_DIR:Ghostship>/Contents/Frameworks/libSDL3.dylib' && chmod u+w '$<TARGET_BUNDLE_DIR:Ghostship>/Contents/Frameworks/libSDL3.dylib'; fi"
        COMMENT "Relinking dylibs into the .app bundle (incl. SDL3 for sdl2-compat)"
        VERBATIM
    )
endif()

add_custom_command(TARGET Ghostship POST_BUILD
    COMMAND codesign --force --deep --sign - --options runtime --entitlements ${ENTITLEMENTS_FILE} "$<TARGET_BUNDLE_DIR:Ghostship>"
    COMMENT "Ad-hoc codesigning Ghostship.app"
    VERBATIM
)
