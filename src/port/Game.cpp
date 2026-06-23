#include <libultraship.h>

#include <fast/interpreter.h>
#include "Engine.h"

#ifdef __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#endif

extern "C" {
#include "audio/external.h"
#include "game/game_init.h"
#include "sm64.h"
}

void alloc_pool() {
    static u64 pool[1024 * 1024 * 4];
    main_pool_init(pool, pool + sizeof(pool) / sizeof(pool[0]));
    gEffectsMemoryPool = mem_pool_init(0x4000, MEMORY_POOL_LEFT);
}

extern "C" void exec_display_list(SPTask* spTask) {
    GameEngine::ProcessGfxCommands((Gfx*)spTask->task.t.data_ptr);
}

void push_frame() {
    GameEngine::StartAudioFrame();
    GameEngine::Instance->StartFrame();
    thread5_iteration();
    GameEngine::EndAudioFrame();
}

#ifdef _WIN32
int SDL_main(int argc, char** argv) {
#else
int main(int argc, char* argv[]) {
#endif
#ifdef __APPLE__
    // Disable the macOS "press and hold" accent/diacritic popup for this app. SDL keeps a Cocoa text
    // input context active, so holding a movement key is interpreted as holding a letter key in a text
    // field, and macOS shows the accent picker instead of repeating it. Per-app equivalent of
    // `defaults write -app <App> ApplePressAndHoldEnabled -bool false`; key repeat still works.
    CFPreferencesSetAppValue(CFSTR("ApplePressAndHoldEnabled"), kCFBooleanFalse, kCFPreferencesCurrentApplication);
    CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
    // Default the writable data folder to ~/Library/Application Support/com.ghostship, mirroring the
    // SHIP_HOME value in the .app's Info.plist (LSEnvironment); overwrite=0 means the plist/user env
    // wins. This fallback only matters when running the raw binary (else it lands in the cwd).
    setenv("SHIP_HOME", "~/Library/Application Support/com.ghostship", 0);
#endif
    GameEngine::Create(argc, argv);
    alloc_pool();
    audio_init();
    sound_init();
    thread5_game_loop();
    while (WindowIsRunning()) {
        push_frame();
    }
    GameEngine::Instance->Destroy();
    return 0;
}