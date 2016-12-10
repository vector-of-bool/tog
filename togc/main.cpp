#include <iostream>
#include <sstream>

#include <boost/asio.hpp>
#include <boost/filesystem.hpp>
#include <boost/optional.hpp>
#include <boost/algorithm/string/replace.hpp>

#include <json.hpp>

namespace asio = boost::asio;
using boost::asio::ip::tcp;
using boost::optional;
using boost::none;

using std::string;
using std::vector;

optional<string> environ_option(const char* key) {
    auto strptr = std::getenv(key);
    if (strptr) {
        return string(strptr);
    } else {
        return none;
    }
}

optional<string> environ_option(const std::string& str) { return environ_option(str.data()); }

std::uint32_t byte_swap(std::uint32_t ret) {
     auto cptr = reinterpret_cast<char*>(&ret);
     using std::swap;
     swap(cptr[0], cptr[3]);
     swap(cptr[1], cptr[2]);
     return ret;
}

void message(const char* msg) {
    if (environ_option("TOG_DEBUG")) {
        std::cerr << "[togc] " << msg << '\n';
    }
}

void message(const string& str) {
    message(str.data());
}


int real_main(int argc, char** argv, char** env) {
    message("This is togc");
    nlohmann::json data{
        { "method", "compile" }, { "params", std::vector<std::string>{ argv + 1, argv + argc } },
    };
    auto envs = nlohmann::json::object();
    for (auto eptr = env; *eptr != nullptr; ++eptr) {
        string env = *eptr;
        const auto eq_pos = env.find('=');
        envs[env.substr(0, eq_pos)] = env.substr(eq_pos+1);
    }
    data["environ"] = envs;
    data["working_dir"] = boost::filesystem::current_path().string();
    const auto body = data.dump();

    asio::io_service ios;

    std::array<char, 4> size_buf;
    auto& length = reinterpret_cast<std::uint32_t&>(size_buf);
    length = static_cast<std::uint32_t>(body.size());
    length = byte_swap(length);

    tcp::socket socket{ ios };
    message("Connecting to localhost:8263");
    auto loopback = asio::ip::address_v4::loopback();
    auto ep = tcp::endpoint(loopback, 8263);
    socket.connect(ep);
    message("Connecting to localhost:8263 - Done");
    message("Writing message");
    message("Message content: " + body);
    asio::write(socket, asio::buffer(size_buf));
    asio::write(socket, asio::buffer(body));
    message("Writing message - Done");

    asio::read(socket, asio::buffer(size_buf));
    length = byte_swap(length);
    asio::streambuf buf;
    std::string readbuf;
    readbuf.resize(length);
    asio::read(socket, asio::buffer(&readbuf[0], readbuf.size()));
    const auto response = nlohmann::json::parse(readbuf);
    auto stdout_iter = response.find("stdout");
    if (stdout_iter != response.end()) {
        auto stdout_str = stdout_iter->operator string();
        boost::replace_all(stdout_str, "\r\n", "\n");
        std::cout << stdout_str;
    }
    auto stderr_iter = response.find("stderr");
    if (stderr_iter != response.end()) {
        std::cout << stderr_iter->operator string();
    }
    auto retc_iter = response.find("retc");
    if (retc_iter != response.end()) {
        return retc_iter->operator int();
    }
    std::cerr << "togc: warning: Did not receive return code from local compiler driver\n";
    return 0;
}

int main(int argc, char** argv, char** env) {
    try {
        return real_main(argc, argv, env);
    } catch (const boost::system::system_error& e) {
        std::cerr << "togc: fatal: Error communicating with local tog server: " << e.what() << '\n';
        return 2;
    }
}