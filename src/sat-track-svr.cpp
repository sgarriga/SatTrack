//  A simple HTTP server to display captured satellite data
//
#include <cstdio>
#include <iostream>
#include <chrono>
#include "sqlite3++.hpp"
#include "httplib.h"

#include "glob.hpp"

static char *db = nullptr;
static std::string image_dir = "../image/";

std::string make_heading() { return ""; }
template<typename T, typename ... Args>
static std::string make_heading(T first, Args ... args) {
    return std::string("<th>") + first + "</th>" + make_heading(args ...);
}

static std::string make_item() { return ""; }
template<typename T, typename ... Args>
static std::string make_item(T first, Args ... args) {
    return std::string("<td>") + first + "</td>" + make_item(args ...);
}

//static void make_row() { }
template<typename T, typename ... Args>
static std::string make_row(T first, Args ... args) {
    return std::string("<tr>") + make_item(first, args ...) + "</tr>\n";
}

static std::string make_date_row(std::string date) {
    return std::string("<tr><td colspan=\"7\">") + date + "</td></tr>\n";
}

template<typename T, typename ... Args>
static std::string make_header_row(T first, Args ... args) {
    return std::string("<tr>") + make_heading(first, args ...) + "</tr>\n";
}

static std::string head() {
    return R"(
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<link rel="stylesheet" href="sat-track.css">
<title>SatCom</title>
</head>
<body>)";
}

static std::string tail() {
    return R"(
</body>
</html>)";
}


std::vector <std::string>file_list(std::string safeSatName, long passStart) {
    std::time_t t = static_cast<std::time_t>(passStart);
    char buff[64];
    strftime(buff, sizeof(buff), "%Y%m%d%H%M%S", gmtime(&t));
    std::string wildcard = image_dir + safeSatName + "-" + buff + "*.png";
    auto files = Glob(wildcard);
    return files;
}

std::string files(std::string safeSatName, long passStart)
{
    std::string table = "";
    try {
            table += "<table>\n";
            auto files = file_list(safeSatName, passStart);
            table += make_header_row("Images");
            for (auto & elem : files) {
                table += make_row(elem + "<br><img src=\"" + elem + "\">");
            }
        table += "</table>\n";
    }
    catch (Exception const & e) {
        printf("%s (%d)\n", e.Message.c_str(), e.Result);
    }
    return table;
}

std::string make_safe(std::string in) {
    std::string out = in;
    std::replace(out.begin(), out.end(), ' ', '_');
    std::erase(out, '(');
    std::erase(out, '}');
    return out;
}

std::string passes()
{
    std::string table = "";
    try {
        Connection connection = Connection(db);

        Statement statement(connection, "select sat_name, date(pass_start, 'unixepoch', 'localtime'), time(pass_start, 'unixepoch', 'localtime'), time(pass_end, 'unixepoch', 'localtime'), max_elev, direction, azimuth_at_max, device, signal_type, status, pass_start from transits order by pass_start desc");

        table += "<table>\n";
        table += make_header_row("Satellite", "Pass Start", "Pass End", "Max. Elevation" , "Azimuth", "Direction", "Images Extracted");
        std::string date = "";
        for (Row pass : statement) {
            std::string pDate = pass.GetString(1); // date-start
            if (pDate != date) {
                date = pDate;
                table += make_date_row(date);
            }
            std::string elev = std::string(pass.GetString(4)) + "&deg;";
            std::string safeSatName = make_safe(pass.GetString(0));
            auto files = file_list(safeSatName, std::atol(pass.GetString(10)));

            std::string cnt;
            if (files.size()) {
                cnt = "<a href=\"files?sat-name=" + safeSatName + "&start=" + pass.GetString(10) + "\">" + std::to_string(files.size()) + "</a>";
            }
            else {
                cnt = "0";
            }

            table += make_row(pass.GetString(0), // sat_name
                     pass.GetString(2),          // time-start
                     pass.GetString(3),          // time-end
                     elev,                       // max. elev.
                     pass.GetString(6),          // azimuth @ max.
                     pass.GetString(5),          // dir
                     cnt);                       // extracted file count
        }
        table += "</table>\n";
    }
    catch (Exception const & e) {
        printf("%s (%d)\n", e.Message.c_str(), e.Result);
    }
    return table;
}

int main(int argc, char *argv[])
{
  int port = 8080;

  for (int i = 1; i < argc; i++) {
    if (argv[i][0] == '-') {
         switch (argv[i][1]) {
             case 'h': 
                  std::cout << "Usage:" << std::endl;
                  std::cout << std::string(argv[0]) << " [-p port#] [-h] database" << std::endl;
                  std::cout << "  -p port# - use port other than 8080" << std::endl;
                  std::cout << "  -h       - display usage information" << std::endl;
                  exit(0);

             case 'p': 
                  port = atoi(argv[++i]); // -p port#
                  break;
             default:
                  std::cout << "Option " << argv[i] << " ignored" << std::endl;
         }
    }
    else {
        db = argv[i];
        if (argc > (++i)) {
          std::cout << "Additional arguments ignored" << std::endl;
        }
        break;
    }
  }


  httplib::Server svr;
  auto ret = svr.set_mount_point("/", "../www"); // everything in here is
                                                 // served by default
  if (!ret) {
    // The specified base directory doesn't exist...
  }

  svr.Get("/", [](const httplib::Request& /* req */, httplib::Response& res) {
    std::string body = head();
    body += passes();
    body += tail();
    res.set_content(body.c_str(), "text/html");
  });

  svr.Get("/files", [](const httplib::Request& req, httplib::Response& res) {
    std::string body = head();
    body += files(req.get_param_value("sat-name"), std::atol(req.get_param_value("start").c_str()));
    body += tail();
    res.set_content(body.c_str(), "text/html");
  });

  svr.Get("/image/:id", [&](const httplib::Request& req, httplib::Response& res){
    auto id = req.path_params.at("id");
    std::ifstream in(image_dir + id, std::ios::in | std::ios::binary);
    if(in){
        std::ostringstream contents;
        contents << in.rdbuf();
        in.close();
        res.set_content(contents.str(), "image/png");
    }else{
        res.status = 404;
    }
   });


  svr.listen("0.0.0.0", port);
}
