// This is free and unencumbered software released into the public domain.
// For more information, please refer to <https://unlicense.org>.

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <objidl.h>     // Needed by GDI+ headers for IStream.
#include <windows.h>
#include <windowsx.h>   // GET_X_LPARAM, GET_Y_LPARAM.
#include <dwmapi.h>     // MARGINS, DWM functions.
#include <gdiplus.h>
#include <shlobj.h>
#include <shellapi.h>
#include <string>
#include <stdexcept>
#include <thread>

#define MINIZ_NO_STDIO
#define MINIZ_NO_ARCHIVE_WRITING_APIS
#include "miniz.h"

#include "resource.h"

namespace {

const COLORREF kGoogleBlue   = 0xFF4285F4;
const COLORREF kGoogleRed    = 0xFFEA4335;
const COLORREF kGoogleYellow = 0xFFFBBC05;
const COLORREF kGoogleGreen  = 0xFF34A853;
const COLORREF kTextGray     = 0xFF63635F;
const COLORREF kErrorRed     = 0xFF0000B3;
const COLORREF kTrackGray    = 0xFFE0E0E0;

const int kWindowWidth  = 420;
const int kWindowHeight = 320;
const int kShimmerTimerId = 1;
const int kCloseBtnSize = 32;
const int kCloseBtnX = kWindowWidth - 8 - kCloseBtnSize;
const int kCloseBtnY = 8;

struct InstallerState {
    std::wstring status_text = L"Installing Gallium...";
    double progress = 0.0;
    bool is_complete = false;
    bool has_error = false;
    bool close_hovered = false;
    double shimmer_offset = 0.0;
    Gdiplus::Bitmap* logo_bitmap = nullptr;
    Gdiplus::PrivateFontCollection* font_collection = nullptr;
    Gdiplus::Font* status_font = nullptr;
};

InstallerState g_state;
HWND g_hwnd = nullptr;

std::wstring Utf8ToWide(const char* utf8) {
    if (!utf8) return L"";
    int len = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, nullptr, 0);
    if (len <= 0) return L"";
    std::wstring result(len - 1, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, utf8, -1, &result[0], len);
    return result;
}

std::string WideToUtf8(const std::wstring& wide) {
    if (wide.empty()) return "";
    int len = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, nullptr, 0, nullptr, nullptr);
    if (len <= 0) return "";
    std::string result(len - 1, '\0');
    WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, &result[0], len, nullptr, nullptr);
    return result;
}

Gdiplus::Color ColorFromCOLORREF(COLORREF c) {
    return Gdiplus::Color(255, GetRValue(c), GetGValue(c), GetBValue(c));
}

bool LoadResourceBytes(HMODULE h_module, int resource_id, const wchar_t* resource_type,
                       void** out_bytes, DWORD* out_size) {
    HRSRC h_res = FindResourceW(h_module, MAKEINTRESOURCEW(resource_id), resource_type);
    if (!h_res) return false;
    HGLOBAL h_data = LoadResource(h_module, h_res);
    if (!h_data) return false;
    *out_size = SizeofResource(h_module, h_res);
    *out_bytes = LockResource(h_data);
    return (*out_bytes != nullptr && *out_size > 0);
}

void InitResources(HMODULE h_module) {
    void* logo_bytes = nullptr;
    DWORD logo_size = 0;
    if (LoadResourceBytes(h_module, IDB_LOGO, L"PNG", &logo_bytes, &logo_size)) {
        HGLOBAL h_mem = GlobalAlloc(GMEM_MOVEABLE, logo_size);
        if (h_mem) {
            void* p = GlobalLock(h_mem);
            memcpy(p, logo_bytes, logo_size);
            GlobalUnlock(h_mem);
            IStream* stream = nullptr;
            if (CreateStreamOnHGlobal(h_mem, TRUE, &stream) == S_OK) {
                g_state.logo_bitmap = new Gdiplus::Bitmap(stream);
                stream->Release();
            }
        }
    }

    void* font_bytes = nullptr;
    DWORD font_size = 0;
    if (LoadResourceBytes(h_module, IDR_FONT, L"FONT", &font_bytes, &font_size)) {
        g_state.font_collection = new Gdiplus::PrivateFontCollection();
        g_state.font_collection->AddMemoryFont(font_bytes, font_size);
        Gdiplus::FontFamily font_family(L"Outfit", g_state.font_collection);
        g_state.status_font = new Gdiplus::Font(&font_family, 14.0f,
                                                 Gdiplus::FontStyleRegular,
                                                 Gdiplus::UnitPixel);
    } else {
        g_state.status_font = new Gdiplus::Font(L"Segoe UI", 14.0f,
                                                 Gdiplus::FontStyleRegular,
                                                 Gdiplus::UnitPixel);
    }
}

void DrawCloseButton(Gdiplus::Graphics& g, bool enabled, bool hovered) {
    int x = kCloseBtnX;
    int y = kCloseBtnY;

    Gdiplus::SolidBrush bg_brush(hovered && enabled
        ? Gdiplus::Color(15, 0, 0, 0)
        : Gdiplus::Color(0, 255, 255, 255));
    g.FillRectangle(&bg_brush, static_cast<float>(x), static_cast<float>(y), 32.0f, 32.0f);

    Gdiplus::Color icon_color;
    if (!enabled) {
        icon_color = Gdiplus::Color(77, 154, 160, 166);
    } else if (hovered) {
        icon_color = Gdiplus::Color(178, 0, 0, 0);
    } else {
        icon_color = Gdiplus::Color(255, 154, 160, 166);
    }

    float cx = static_cast<float>(x + 8);
    float cy = static_cast<float>(y + 8);
    float icon_size = 16.0f;
    float pad = 3.5f;

    Gdiplus::Pen pen(icon_color, 1.5f);
    g.DrawLine(&pen, cx + pad, cy + pad, cx + icon_size - pad, cy + icon_size - pad);
    g.DrawLine(&pen, cx + icon_size - pad, cy + pad, cx + pad, cy + icon_size - pad);
}

void DrawProgressBar(Gdiplus::Graphics& g, double progress, double shimmer_offset,
                     float bar_y) {
    float bar_x = (kWindowWidth - 280) / 2.0f;
    float bar_w = 280.0f;
    float bar_h = 3.0f;

    Gdiplus::SolidBrush track_brush(ColorFromCOLORREF(kTrackGray));
    g.FillRectangle(&track_brush, bar_x, bar_y, bar_w, bar_h);

    if (progress <= 0.0) return;

    float fill_w = static_cast<float>(bar_w * progress);
    if (fill_w < 1.0f) fill_w = 1.0f;

    Gdiplus::LinearGradientBrush gradient_brush(
        Gdiplus::Point(static_cast<int>(bar_x), 0),
        Gdiplus::Point(static_cast<int>(bar_x + fill_w), 0),
        ColorFromCOLORREF(kGoogleBlue),
        ColorFromCOLORREF(kGoogleGreen)
    );
    Gdiplus::Color gradient_colors[] = {
        ColorFromCOLORREF(kGoogleBlue),
        ColorFromCOLORREF(kGoogleRed),
        ColorFromCOLORREF(kGoogleYellow),
        ColorFromCOLORREF(kGoogleGreen)
    };
    float positions[] = { 0.0f, 0.33f, 0.66f, 1.0f };
    gradient_brush.SetInterpolationColors(gradient_colors, positions, 4);

    g.FillRectangle(&gradient_brush, bar_x, bar_y, fill_w, bar_h);

    if (progress < 1.0) {
        float shimmer_begin = bar_x + fill_w * (static_cast<float>(shimmer_offset) * 2.0f - 1.0f);
        float shimmer_end = bar_x + fill_w * (static_cast<float>(shimmer_offset) * 2.0f);

        Gdiplus::LinearGradientBrush shimmer_brush(
            Gdiplus::Point(static_cast<int>(shimmer_begin), 0),
            Gdiplus::Point(static_cast<int>(shimmer_end), 0),
            Gdiplus::Color(0, 255, 255, 255),
            Gdiplus::Color(76, 255, 255, 255)
        );
        Gdiplus::Color shimmer_colors[] = {
            Gdiplus::Color(0, 255, 255, 255),
            Gdiplus::Color(76, 255, 255, 255),
            Gdiplus::Color(0, 255, 255, 255)
        };
        float shimmer_pos[] = { 0.0f, 0.5f, 1.0f };
        shimmer_brush.SetInterpolationColors(shimmer_colors, shimmer_pos, 3);

        g.FillRectangle(&shimmer_brush, bar_x, bar_y, fill_w, bar_h);
    }
}

void OnPaint(HWND hwnd) {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(hwnd, &ps);

    RECT rc;
    GetClientRect(hwnd, &rc);
    int width = rc.right - rc.left;
    int height = rc.bottom - rc.top;

    HDC hdc_mem = CreateCompatibleDC(hdc);
    HBITMAP hbm_mem = CreateCompatibleBitmap(hdc, width, height);
    HBITMAP hbm_old = reinterpret_cast<HBITMAP>(SelectObject(hdc_mem, hbm_mem));

    Gdiplus::Graphics g(hdc_mem);
    g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    g.SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);

    g.Clear(Gdiplus::Color(255, 255, 255));

    // Layout: logo 72px, gap 24px, text ~18px, gap 20px, progress bar.
    float total_content_h = 72.0f + 24.0f + 18.0f + 20.0f + 3.0f;
    float start_y = (kWindowHeight - total_content_h) / 2.0f;

    if (g_state.logo_bitmap) {
        float logo_x = (kWindowWidth - 72) / 2.0f;
        g.DrawImage(g_state.logo_bitmap, logo_x, start_y, 72.0f, 72.0f);
    }

    float text_y = start_y + 72.0f + 24.0f;
    Gdiplus::Color text_color = g_state.has_error
        ? ColorFromCOLORREF(kErrorRed)
        : ColorFromCOLORREF(kTextGray);
    Gdiplus::SolidBrush text_brush(text_color);

    Gdiplus::StringFormat format;
    format.SetAlignment(Gdiplus::StringAlignmentCenter);
    format.SetTrimming(Gdiplus::StringTrimmingCharacter);
    format.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);

    Gdiplus::RectF text_rect(0, text_y, static_cast<float>(kWindowWidth), 20.0f);
    g.DrawString(g_state.status_text.c_str(), -1, g_state.status_font,
                 text_rect, &format, &text_brush);

    float bar_y = start_y + 72.0f + 24.0f + 18.0f + 20.0f;
    DrawProgressBar(g, g_state.progress, g_state.shimmer_offset, bar_y);
    DrawCloseButton(g, g_state.is_complete || g_state.has_error, g_state.close_hovered);

    BitBlt(hdc, 0, 0, width, height, hdc_mem, 0, 0, SRCCOPY);

    SelectObject(hdc_mem, hbm_old);
    DeleteObject(hbm_mem);
    DeleteDC(hdc_mem);

    EndPaint(hwnd, &ps);
}

bool CreateShortcut(const std::wstring& shortcut_path,
                    const std::wstring& target_path,
                    const std::wstring& icon_path,
                    const std::wstring& description) {
    IShellLinkW* shell_link = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_IShellLinkW, reinterpret_cast<void**>(&shell_link));
    if (FAILED(hr)) return false;

    shell_link->SetPath(target_path.c_str());
    shell_link->SetIconLocation(icon_path.c_str(), 0);
    shell_link->SetDescription(description.c_str());

    std::wstring work_dir = target_path;
    size_t last_slash = work_dir.find_last_of(L"\\/");
    if (last_slash != std::wstring::npos) work_dir = work_dir.substr(0, last_slash);
    shell_link->SetWorkingDirectory(work_dir.c_str());

    IPersistFile* persist_file = nullptr;
    hr = shell_link->QueryInterface(IID_IPersistFile,
                                     reinterpret_cast<void**>(&persist_file));
    if (SUCCEEDED(hr)) {
        hr = persist_file->Save(shortcut_path.c_str(), TRUE);
        persist_file->Release();
    }
    shell_link->Release();
    return SUCCEEDED(hr);
}

bool RegisterUninstaller(const std::wstring& install_dir, const std::wstring& exe_path) {
    const wchar_t* key_path = L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Gallium";

    HKEY h_key = nullptr;
    LONG result = RegCreateKeyExW(HKEY_CURRENT_USER, key_path, 0, nullptr,
                                   REG_OPTION_NON_VOLATILE, KEY_SET_VALUE,
                                   nullptr, &h_key, nullptr);
    if (result != ERROR_SUCCESS) return false;

    auto set_string = [&](const wchar_t* name, const std::wstring& value) {
        RegSetValueExW(h_key, name, 0, REG_SZ,
                       reinterpret_cast<const BYTE*>(value.c_str()),
                       static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
    };
    auto set_dword = [&](const wchar_t* name, DWORD value) {
        RegSetValueExW(h_key, name, 0, REG_DWORD,
                       reinterpret_cast<const BYTE*>(&value), sizeof(DWORD));
    };

    set_string(L"DisplayName", L"Gallium Editor");
    set_string(L"DisplayVersion", L"0.1.0");
    set_string(L"Publisher", L"dev.gallium");
    set_string(L"InstallLocation", install_dir);
    set_string(L"DisplayIcon", exe_path);

    std::wstring uninstall_cmd =
        L"powershell -NoProfile -Command \"Remove-Item -Recurse -Force \\\""
        + install_dir + L"\\\"; Remove-Item -Path \\\"HKCU:\\"
        + key_path + L"\\\" -Force\"";
    set_string(L"UninstallString", uninstall_cmd);
    set_dword(L"NoModify", 1);
    set_dword(L"NoRepair", 1);

    RegCloseKey(h_key);
    return true;
}

void RunInstallation(HMODULE h_module) {
    // COM is required for IShellLink in this worker thread.
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

    auto update_ui = [](const std::wstring& text, double progress) {
        g_state.status_text = text;
        g_state.progress = progress;
        InvalidateRect(g_hwnd, nullptr, FALSE);
    };

    try {
        update_ui(L"Preparing...", 0.05);

        wchar_t local_app_data[MAX_PATH];
        if (!GetEnvironmentVariableW(L"LOCALAPPDATA", local_app_data, MAX_PATH))
            throw std::runtime_error("Cannot read LOCALAPPDATA");

        std::wstring install_dir = std::wstring(local_app_data) + L"\\Programs\\Gallium";

        update_ui(L"Extracting files...", 0.1);

        void* zip_bytes = nullptr;
        DWORD zip_size = 0;
        if (!LoadResourceBytes(h_module, IDR_ZIP, L"ZIP", &zip_bytes, &zip_size))
            throw std::runtime_error("Cannot load embedded archive");

        mz_zip_archive zip = {};
        if (!mz_zip_reader_init_mem(&zip, zip_bytes, zip_size, 0))
            throw std::runtime_error("Cannot open ZIP archive");

        int total_files = static_cast<int>(mz_zip_reader_get_num_files(&zip));
        int extracted_count = 0;

        for (int i = 0; i < total_files; i++) {
            mz_zip_archive_file_stat file_stat;
            if (!mz_zip_reader_file_stat(&zip, i, &file_stat)) continue;

            std::wstring rel_path = Utf8ToWide(file_stat.m_filename);
            for (auto& ch : rel_path) {
                if (ch == L'/') ch = L'\\';
            }

            if (!rel_path.empty() && rel_path.back() == L'\\') {
                std::wstring dir_path = install_dir + L"\\" + rel_path;
                // SHCreateDirectoryExW fails on trailing backslash.
                if (dir_path.back() == L'\\') dir_path.pop_back();
                SHCreateDirectoryExW(nullptr, dir_path.c_str(), nullptr);
                continue;
            }

            std::wstring file_path = install_dir + L"\\" + rel_path;

            std::wstring parent_dir = file_path;
            size_t last_slash = parent_dir.find_last_of(L"\\/");
            if (last_slash != std::wstring::npos) {
                parent_dir = parent_dir.substr(0, last_slash);
                SHCreateDirectoryExW(nullptr, parent_dir.c_str(), nullptr);
            }

            // CreateFileW is used instead of fopen to support Unicode paths.
            size_t file_size = 0;
            void* file_data = mz_zip_reader_extract_to_heap(&zip, i, &file_size, 0);
            if (!file_data)
                throw std::runtime_error("Failed to extract file: " + WideToUtf8(rel_path));

            HANDLE h_file = CreateFileW(file_path.c_str(), GENERIC_WRITE, 0, nullptr,
                                        CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
            if (h_file == INVALID_HANDLE_VALUE) {
                DWORD err = GetLastError();
                free(file_data);
                std::wstring err_msg = L"Failed to create file: " + file_path
                    + L" (error " + std::to_wstring(err) + L")";
                throw std::runtime_error(WideToUtf8(err_msg));
            }
            DWORD written = 0;
            WriteFile(h_file, file_data, static_cast<DWORD>(file_size), &written, nullptr);
            CloseHandle(h_file);
            free(file_data);
            if (written != file_size)
                throw std::runtime_error("Failed to write file: " + WideToUtf8(rel_path));

            extracted_count++;
            if (extracted_count % 3 == 0 || extracted_count == total_files) {
                update_ui(g_state.status_text, 0.1 + 0.6 * (static_cast<double>(extracted_count) / total_files));
                Sleep(0);
            }
        }

        mz_zip_reader_end(&zip);

        update_ui(L"Creating shortcuts...", 0.8);

        std::wstring exe_path = install_dir + L"\\Gallium.exe";

        wchar_t user_profile[MAX_PATH];
        GetEnvironmentVariableW(L"USERPROFILE", user_profile, MAX_PATH);
        std::wstring desktop_shortcut = std::wstring(user_profile) + L"\\Desktop\\Gallium.lnk";

        if (!CreateShortcut(desktop_shortcut, exe_path, exe_path, L"Gallium Editor"))
            throw std::runtime_error("Failed to create desktop shortcut");

        wchar_t app_data[MAX_PATH];
        GetEnvironmentVariableW(L"APPDATA", app_data, MAX_PATH);
        std::wstring start_menu_shortcut = std::wstring(app_data)
            + L"\\Microsoft\\Windows\\Start Menu\\Programs\\Gallium.lnk";

        if (!CreateShortcut(start_menu_shortcut, exe_path, exe_path, L"Gallium Editor"))
            throw std::runtime_error("Failed to create Start Menu shortcut");

        update_ui(L"Registering application...", 0.9);

        RegisterUninstaller(install_dir, exe_path);

        g_state.is_complete = true;
        update_ui(L"Complete!", 1.0);

        ShellExecuteW(nullptr, L"open", exe_path.c_str(), nullptr, nullptr, SW_SHOW);

        Sleep(500);
        PostMessage(g_hwnd, WM_CLOSE, 0, 0);

    } catch (const std::exception& e) {
        std::string msg = "Installation failed: ";
        msg += e.what();
        g_state.status_text = Utf8ToWide(msg.c_str());
        g_state.has_error = true;
        InvalidateRect(g_hwnd, nullptr, FALSE);
    }

    CoUninitialize();
}

LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_PAINT:
        OnPaint(hwnd);
        return 0;

    case WM_ERASEBKGND:
        // Returning 1 prevents background erasure, which eliminates flicker.
        return 1;

    case WM_TIMER:
        if (wParam == kShimmerTimerId) {
            g_state.shimmer_offset += 0.02;
            if (g_state.shimmer_offset > 1.0) g_state.shimmer_offset = 0.0;
            InvalidateRect(hwnd, nullptr, FALSE);
        }
        return 0;

    case WM_MOUSEMOVE: {
        int x = GET_X_LPARAM(lParam);
        int y = GET_Y_LPARAM(lParam);
        bool was_hovered = g_state.close_hovered;
        g_state.close_hovered = (x >= kCloseBtnX && x <= kCloseBtnX + kCloseBtnSize
                                  && y >= kCloseBtnY && y <= kCloseBtnY + kCloseBtnSize);
        if (g_state.close_hovered != was_hovered)
            InvalidateRect(hwnd, nullptr, FALSE);
        TRACKMOUSEEVENT tme = { sizeof(tme), TME_LEAVE, hwnd, 0 };
        TrackMouseEvent(&tme);
        return 0;
    }

    case WM_MOUSELEAVE:
        if (g_state.close_hovered) {
            g_state.close_hovered = false;
            InvalidateRect(hwnd, nullptr, FALSE);
        }
        return 0;

    case WM_LBUTTONUP: {
        int x = GET_X_LPARAM(lParam);
        int y = GET_Y_LPARAM(lParam);
        if (x >= kCloseBtnX && x <= kCloseBtnX + kCloseBtnSize
            && y >= kCloseBtnY && y <= kCloseBtnY + kCloseBtnSize) {
            if (g_state.is_complete || g_state.has_error) {
                DestroyWindow(hwnd);
            }
        }
        return 0;
    }

    case WM_NCHITTEST: {
        POINT pt = { GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam) };
        ScreenToClient(hwnd, &pt);
        // The close button area is not draggable; the rest acts as a caption bar.
        if (pt.x >= kCloseBtnX && pt.x <= kCloseBtnX + kCloseBtnSize
            && pt.y >= kCloseBtnY && pt.y <= kCloseBtnY + kCloseBtnSize)
            return HTCLIENT;
        return HTCAPTION;
    }

    case WM_CLOSE:
        if (g_state.is_complete || g_state.has_error) {
            DestroyWindow(hwnd);
        }
        return 0;

    case WM_DESTROY:
        KillTimer(hwnd, kShimmerTimerId);
        PostQuitMessage(0);
        return 0;

    default:
        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }
}

void ApplyDwmEffects(HWND hwnd) {
    HMODULE h_dwm = LoadLibraryW(L"dwmapi.dll");
    if (!h_dwm) return;

    // DWMWA_WINDOW_CORNER_PREFERENCE = 33, DWMWCP_ROUND = 2.
    using DwmSetWindowAttributeFn = HRESULT(WINAPI*)(HWND, DWORD, LPCVOID, DWORD);
    auto dwm_set_window_attribute = reinterpret_cast<DwmSetWindowAttributeFn>(
        GetProcAddress(h_dwm, "DwmSetWindowAttribute"));
    if (dwm_set_window_attribute) {
        DWORD preference = 2;  // DWMWCP_ROUND
        dwm_set_window_attribute(hwnd, 33, &preference, sizeof(preference));
    }

    using DwmExtendFrameIntoClientAreaFn = HRESULT(WINAPI*)(HWND, const MARGINS*);
    auto dwm_extend_frame = reinterpret_cast<DwmExtendFrameIntoClientAreaFn>(
        GetProcAddress(h_dwm, "DwmExtendFrameIntoClientArea"));
    if (dwm_extend_frame) {
        MARGINS margins = { 1, 1, 1, 1 };
        dwm_extend_frame(hwnd, &margins);
    }

    FreeLibrary(h_dwm);
}

}  // namespace

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, LPWSTR, int) {
    Gdiplus::GdiplusStartupInput gdiplus_startup_input;
    ULONG_PTR gdiplus_token;
    Gdiplus::GdiplusStartup(&gdiplus_token, &gdiplus_startup_input, nullptr);

    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

    InitResources(hInstance);

    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(wc);
    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wc.hbrBackground = nullptr;
    wc.lpszClassName = L"GalliumInstaller";
    RegisterClassExW(&wc);

    int screen_w = GetSystemMetrics(SM_CXSCREEN);
    int screen_h = GetSystemMetrics(SM_CYSCREEN);
    int x = (screen_w - kWindowWidth) / 2;
    int y = (screen_h - kWindowHeight) / 2;

    g_hwnd = CreateWindowExW(
        WS_EX_APPWINDOW,
        L"GalliumInstaller",
        L"Gallium Installer",
        WS_POPUP | WS_VISIBLE,
        x, y, kWindowWidth, kWindowHeight,
        nullptr, nullptr, hInstance, nullptr
    );

    ApplyDwmEffects(g_hwnd);

    SetTimer(g_hwnd, kShimmerTimerId, 33, nullptr);

    std::thread install_thread(RunInstallation, hInstance);
    install_thread.detach();

    MSG msg;
    while (GetMessage(&msg, nullptr, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    delete g_state.logo_bitmap;
    delete g_state.font_collection;
    delete g_state.status_font;
    CoUninitialize();
    Gdiplus::GdiplusShutdown(gdiplus_token);

    return 0;
}
