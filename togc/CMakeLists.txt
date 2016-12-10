add_executable(togc main.cpp)
target_link_libraries(togc PRIVATE
    Boost::disable_autolinking
    Boost::system
    Boost::filesystem
    nlohmann::json
    )
target_compile_definitions(togc PRIVATE _CRT_SECURE_NO_WARNINGS NOMINMAX)