//also see: https://github.com/dotnet/runtime/issues/73516
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <chrono>
#include <iostream>
#include <thread>
#include <vector>
// Provided by the AppHost NuGet package and installed as an SDK pack
#include <nethost.h>
// Header files copied from https://github.com/dotnet/core-setup
#include "coreclr_delegates.h"
#include "hostfxr.h"

#ifdef WINDOWS
#include <Windows.h>

#define STR(s) L ## s
#define CH(c) L ## c
#define DIR_SEPARATOR L"\\"

#define string_compare wcscmp

#else
#include <dlfcn.h>
#include <limits.h>
#include <string>

#define STR(s) s
#define CH(c) c
#define DIR_SEPARATOR "/"
#define MAX_PATH PATH_MAX

#define string_compare strcmp

#endif

using string_t = std::basic_string<char_t>;


//#include "bridge2net.h"

// Globals to hold hostfxr exports
hostfxr_initialize_for_dotnet_command_line_fn init_for_cmd_line_fptr;
hostfxr_initialize_for_runtime_config_fn init_for_config_fptr;
hostfxr_get_runtime_delegate_fn get_delegate_fptr;
hostfxr_run_app_fn run_app_fptr;
hostfxr_close_fn close_fptr;

// Forward declarations
bool load_hostfxr(const char_t *app);
load_assembly_and_get_function_pointer_fn get_dotnet_load_assembly(const char_t *assembly);

struct lib_args
{
};

static bool ends_with(const string_t& str, const string_t& suffix)
{
    return str.size() >= suffix.size() && str.compare(str.size()-suffix.size(), suffix.size(), suffix) == 0;
}    

string_t get_env( string_t const & key )
{
    char * val = getenv( key.c_str() );
    return val == NULL ? STR("") : STR(val);
}

std::vector<string_t> split_string(string_t s, string_t delimiter) {
    size_t pos_start = 0, pos_end, delim_len = delimiter.length();
    std::string token;
    std::vector<std::string> res;

    while ((pos_end = s.find(delimiter, pos_start)) != std::string::npos) {
        token = s.substr (pos_start, pos_end - pos_start);
        pos_start = pos_end + delim_len;
        res.push_back (token);
    }

    res.push_back (s.substr (pos_start));
    return res;
}

bool call_net(const char* path, const char* dllName, const char* entryType, const char* method);

// parse _NADLER env
void snapit() {
    string_t _handlerVal = get_env(STR("_HANDLER"));
	string_t target_location = get_env(STR("NET_RUNTIME_PATH"));
    //putenv((char*)net_sdk_path.c_str());

	call_net(target_location.c_str(), "Snapper.Runtime.Delegator", "Snapper.Runtime.Delegator.EntryPoint", "StartUnmanagedOnly");
}

bool call_net(const char* path, const char* dllName, const char* entryType, const char* method) {
    //std::cout << "path: " << path << std::endl;;
    // format path
    string_t root_path = STR(path);
    if (!ends_with(path, STR(DIR_SEPARATOR))) {
        root_path += DIR_SEPARATOR;
    }
    //std::cout << "root_path: " << root_path << std::endl;

    // Load HostFxr and get exported hosting functions
    if (!load_hostfxr(nullptr))
    {
        assert(false && "Failure: load_hostfxr()");
        return EXIT_FAILURE;
    }   

    // Initialize and start the .NET Core runtime
    const string_t config_path = root_path + STR(dllName + ".runtimeconfig.json");
    load_assembly_and_get_function_pointer_fn load_assembly_and_get_function_pointer = nullptr;
    load_assembly_and_get_function_pointer = get_dotnet_load_assembly(config_path.c_str());
    assert(load_assembly_and_get_function_pointer != nullptr && "Failure: get_dotnet_load_assembly()");

    // Load managed assembly and get function pointer to a managed method
    const string_t dotnetlib_path = root_path + STR(dllName + ".dll");
    //std::cout << "dotnetlib_path: " << dotnetlib_path << std::endl;
    string_t type_name = STR(entryType);
    type_name += STR(", ");
    type_name += dllName;
    //std::cout << "type_name: " << type_name << std::endl;
    const char_t *dotnet_type = type_name.c_str();
    const char_t *dotnet_type_method = STR(method);

    lib_args args = {};

    // Function pointer to managed delegate
    // Run managed code
    // component_entry_point_fn start = nullptr;
    // int rc = load_assembly_and_get_function_pointer(
    //     dotnetlib_path.c_str(),
    //     dotnet_type,
    //     dotnet_type_method,
    //     nullptr /*delegate_type_name*/,
    //     nullptr,
    //     (void**)&start);
    // assert(rc == 0 && start != nullptr && "Failure: load_assembly_and_get_function_pointer(Start)");
    // start(&args, sizeof(args));


    // UnmanagedCallersOnly
    typedef void (CORECLR_DELEGATE_CALLTYPE *custom_entry_point_fn)(lib_args args);
    custom_entry_point_fn start_unmanaged = nullptr;
    int rc2 = load_assembly_and_get_function_pointer(
        dotnetlib_path.c_str(),
        dotnet_type,
        STR(method) /*method_name*/,
        UNMANAGEDCALLERSONLY_METHOD,
        nullptr,
        (void**)&start_unmanaged);
    assert(rc2 == 0 && start_unmanaged != nullptr && "Failure: load_assembly_and_get_function_pointer(StartUnmanagedOnly)");
    start_unmanaged(args);

    return true;
}

/********************************************************************************************
 * Function used to load and activate .NET Core
 ********************************************************************************************/

// Forward declarations
void *load_library(const char_t *);
void *get_export(void *, const char *);

#ifdef WINDOWS
void *load_library(const char_t *path)
{
    HMODULE h = ::LoadLibraryW(path);
    assert(h != nullptr);
    return (void*)h;
}
void *get_export(void *h, const char *name)
{
    void *f = ::GetProcAddress((HMODULE)h, name);
    assert(f != nullptr);
    return f;
}
#else
void *load_library(const char_t *path)
{
    void *h = dlopen(path, RTLD_LAZY | RTLD_LOCAL);
    assert(h != nullptr);
    return h;
}
void *get_export(void *h, const char *name)
{
    void *f = dlsym(h, name);
    assert(f != nullptr);
    return f;
}
#endif

// <SnippetLoadHostFxr>
// Using the nethost library, discover the location of hostfxr and get exports
bool load_hostfxr(const char_t *assembly_path)
{
    get_hostfxr_parameters params { sizeof(get_hostfxr_parameters), assembly_path, nullptr };
    // Pre-allocate a large buffer for the path to hostfxr
    char_t buffer[MAX_PATH];
    size_t buffer_size = sizeof(buffer) / sizeof(char_t);
    int rc = get_hostfxr_path(buffer, &buffer_size, &params);
    if (rc != 0)
        return false;

    // Load hostfxr and get desired exports
    // NOTE: The .NET Runtime does not support unloading any of its native libraries. Running
    // dlclose/FreeLibrary on any .NET libraries produces undefined behavior.
    void *lib = load_library(buffer);
    init_for_cmd_line_fptr = (hostfxr_initialize_for_dotnet_command_line_fn)get_export(lib, "hostfxr_initialize_for_dotnet_command_line");
    init_for_config_fptr = (hostfxr_initialize_for_runtime_config_fn)get_export(lib, "hostfxr_initialize_for_runtime_config");
    get_delegate_fptr = (hostfxr_get_runtime_delegate_fn)get_export(lib, "hostfxr_get_runtime_delegate");
    run_app_fptr = (hostfxr_run_app_fn)get_export(lib, "hostfxr_run_app");
    close_fptr = (hostfxr_close_fn)get_export(lib, "hostfxr_close");

    return (init_for_config_fptr && get_delegate_fptr && close_fptr);
}
// </SnippetLoadHostFxr>

// <SnippetInitialize>
// Load and initialize .NET Core and get desired function pointer for scenario
load_assembly_and_get_function_pointer_fn get_dotnet_load_assembly(const char_t *config_path)
{
    // Load .NET Core
    void *load_assembly_and_get_function_pointer = nullptr;
    hostfxr_handle cxt = nullptr;
    int rc = init_for_config_fptr(config_path, nullptr, &cxt);
    if (rc != 0 || cxt == nullptr)
    {
        std::cerr << "Init failed: " << std::hex << std::showbase << rc << std::endl;
        close_fptr(cxt);
        return nullptr;
    }

    // Get the load assembly function pointer
    rc = get_delegate_fptr(
        cxt,
        hdt_load_assembly_and_get_function_pointer,
        &load_assembly_and_get_function_pointer);
    if (rc != 0 || load_assembly_and_get_function_pointer == nullptr)
        std::cerr << "Get delegate failed: " << std::hex << std::showbase << rc << std::endl;

    close_fptr(cxt);
    return (load_assembly_and_get_function_pointer_fn)load_assembly_and_get_function_pointer;
}
// </SnippetInitialize>
