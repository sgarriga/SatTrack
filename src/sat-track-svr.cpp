//  A simple HTTP server to display captured satellite data and
//  manage what satellites we capture
//
#include <cstdio>
#include <iostream>
#include <chrono>
#include <filesystem>
#include "sqlite3++.hpp"
#include "httplib.h"

#include "glob.hpp"

static char *db = nullptr;
static std::string image_dir = "/home/pi/SatTrack/www/img/";
static std::string wav_dir = "/home/pi/SatTrack/www/wav/";
static std::string utc_delta_s = "UTC";

// a set of routines to build an HTML table with an arbitrary number of columns
std::string make_heading() { return ""; }
template<typename T, typename ... Args>
static std::string make_heading(T first, Args ... args) {
	return std::string("<th>") + first + "</th>" + make_heading(args ...);
}
//
static std::string make_item() { return ""; }
template<typename T, typename ... Args>
static std::string make_item(T first, Args ... args) {
	return std::string("<td>") + first + "</td>" + make_item(args ...);
}
//
template<typename T, typename ... Args>
static std::string make_row(T first, Args ... args) {
	return std::string("<tr>") + make_item(first, args ...) + "</tr>\n";
}
//
template<typename T, typename ... Args>
static std::string make_header_row(T first, Args ... args) {
	return std::string("<tr>") + make_heading(first, args ...) + "</tr>\n";
}
//
// and a special case...
static std::string make_date_row(std::string date) {
	return std::string("<tr><td class=\"date\" colspan=\"7\">") + date + "</td></tr>\n";
}

// read a 'template' file into a string
// - this will generally have one or more {{}} or {{vvv}} strings embedded
//   to be replaced
std::string getTemplate(const char *name) {
	std::ifstream ifs(name, std::ios::in | std::ios::binary | std::ios::ate);
	std::ifstream::pos_type size = ifs.tellg();
	ifs.seekg(0, std::ios::beg);
	std::vector<char> bytes(size);
	ifs.read(bytes.data(), size);
	return std::string(bytes.data(), size);
}

// greate a filename root
std::string root_name(std::string safeSatName, long passStart) {
	std::time_t t = static_cast<std::time_t>(passStart);
	char buff[64];
	strftime(buff, sizeof(buff), "%Y%m%d%H%M%S", gmtime(&t));
	return safeSatName + "-" + buff;
}

// get a vector list of image files associated with a satellite pass
std::vector <std::string>file_list(std::string safeSatName, long passStart) {
	std::string wildcard = image_dir + root_name(safeSatName, passStart) + "*.png";
	auto files = Glob(wildcard);
	wildcard = image_dir + root_name(safeSatName, passStart) + "*.bmp";
	auto files2 = Glob(wildcard);
        files.insert(files.end(), files2.begin(), files2.end());
	return files;
}

// what is our UTC delta?
const std::string utc_delta() {
	time_t     now = time(0);
	struct tm  tstruct;
	char       buf[80];
	tstruct = *localtime(&now);
	strftime(buf, sizeof(buf), "UTC%z", &tstruct);
	return buf;
}

// generate the 'edit' and 'delete' links for a satellite
std::string sat_updt_links(std::string sat_id) {
	std::string ret = "";
	ret += "<a href=\"sat_edit?sat_row=" + sat_id + "\">";
	ret += "<img class=\"icon\" src=\"./edit-icon.png\" alt=\"edit\">";
	ret += "</a>&nbsp;&nbsp;";
	ret += "<a href=\"sat_del?sat_row=" + sat_id + "\">";
	ret += "<img class=\"icon\" src=\"./delete-icon.png\" alt=\"delete\">";
	ret += "</a>";
	return ret;
}

// display the satellites we are tracking
std::string satellites() {
	std::string table = "";
	try {
		Connection connection = Connection(db);

		Statement statement(connection, "SELECT ROWID, * FROM SATELLITES ORDER BY name");
		table += "<table>\n";
		table += make_header_row("Name", "Freq. (MHz)", "Gain", "Signal Type" , "Device ID", "Bias Tee", "Minimum Elevation", "Edit/Delete/Add");
		for (Row sat : statement) {
			table += make_row(sat.GetString(1),
					sat.GetString(2),
					sat.GetString(3),
					sat.GetString(4),
					sat.GetString(5),
					sat.GetString(6),
					sat.GetString(7),
					sat_updt_links(sat.GetString(0)));
		}
		table += make_row("",
				"",
				"",
				"",
				"",
				"",
				"",
				"<a href=\"sat_add\"><img class=\"icon\" src=\"./add-icon.png\" alt=\"add\"></a>");
		table += "</table>\n";
	}
	catch (Exception const & e) {
		printf("%s (%d)\n", e.Message.c_str(), e.Result);
	}
	return table;
}

// delete a tracked satellite entry (by row id)
void sat_del(std::string sat_row_id) {
	try {
		Connection connection = Connection(db);
		std::string del = std::string("DELETE FROM satellites WHERE rowid=") + sat_row_id;
		Execute(connection, del.c_str());
	}
	catch (Exception const & e) {
		printf("%s (%d)\n", e.Message.c_str(), e.Result);
	}
}

// delete a satellite pass entry (by row id) - if it's not complete or in-progress
void pass_del(std::string pass_row_id) {
	try {
		Connection connection = Connection(db);

		// delete the pass if it hasn't happened yet or isn't in progress
		std::string del = std::string("DELETE FROM TRANSITS WHERE rowid=") + pass_row_id + " AND status!=\"complete\" AND status!=\"active\";";
		Execute(connection, del.c_str());

	}
	catch (Exception const & e) {
		printf("%s (%d)\n", e.Message.c_str(), e.Result);
	}
}

// save a newly created, or edited tracked satellite entry
void sat_save(httplib::Params params) {
	try {
		Connection connection = Connection(db);
		std::string sat_name = "";

		// saving an 'add' we have a norad_names row_id, not a name
		if (params.find("norad_row") != params.end()) {
			std::string name_query = "SELECT name FROM norad_names WHERE rowid=" + params.find("norad_row")->second;
			for (Row row : Statement(connection, name_query.c_str())) {
				sat_name =  row.GetString(0);
				if (sat_name.size()) {
					sat_name = sat_name.substr(0, sat_name.find_last_not_of(" ")+1);
				}
				break; // only 1 match expected
			}
		}
		else {
			sat_name = params.find("sat_name")->second;
		}

		std::string insert = std::string("INSERT INTO satellites VALUES (")
				+ "\"" + sat_name + "\", " 
				+ params.find("freq")->second + ", " 
				+ params.find("gain")->second + ", " 
				+ "\"" + params.find("signal")->second + "\", " 
				+ params.find("dev")->second + ", " 
				+ "\"" + params.find("biast")->second + "\", " 
				+ params.find("elev")->second + ");";
		Execute(connection, insert.c_str());

		// if this update was from an 'edit' then purge the old row
		if (params.find("del_sat_row") != params.end()) {
			sat_del(params.find("del_sat_row")->second);
		}

	}
	catch (Exception const & e) {
		printf("%s (%d)\n", e.Message.c_str(), e.Result);
	}
}

// present the 'edit' for for a tracked satellite
std::string sat_edit(std::string row_id) {
	std::string body = "";
	try {
		body += getTemplate("/home/pi/SatTrack/www/edit_template");

		Connection connection = Connection(db);
		std::string query = "SELECT * FROM SATELLITES WHERE rowid=" + row_id;
		for (Row sat : Statement(connection, query.c_str())) {
			body.replace(body.find("{{ROW}}"), 7, row_id);
			do {
				body.replace(body.find("{{NAME}}"), 8, sat.GetString(0));
			} while (body.find("{{NAME}}") != std::string::npos);
			body.replace(body.find("{{FREQ}}"), 8, sat.GetString(1));
			body.replace(body.find("{{GAIN}}"), 8, sat.GetString(2));
			std::string tgt = std::string("\"signal\" value=\"") + sat.GetString(3) + "\"";
			body.replace(body.find(tgt), tgt.size(), tgt + " checked");
			tgt = std::string("\"dev\" value=\"") + sat.GetString(4) + "\"";
			body.replace(body.find(tgt), tgt.size(), tgt + " checked");
			tgt = std::string("\"biast\" value=\"") + sat.GetString(5) + "\"";
			body.replace(body.find(tgt), tgt.size(), tgt + " checked");
			body.replace(body.find("{{ELEV}}"), 8, sat.GetString(6));
			break; // only 1 match expected
		}
	}
	catch (Exception const & e) {
		printf("%s (%d)\n", e.Message.c_str(), e.Result);
	}
	return body;
}

// create the satellite names dropdown for the 'add' form
std::string satellite_opts() {
	std::string opts = "";
	try {
		Connection connection = Connection(db);

		Statement statement(connection, "SELECT rowid, name FROM norad_names ORDER BY name");
		for (Row sat : statement) {
			opts += std::string("<option value=\"") + sat.GetString(0) + "\">" + sat.GetString(1) + "</option>\n";
		}
	}
	catch (Exception const & e) {
		printf("%s (%d)\n", e.Message.c_str(), e.Result);
	}
	return opts;
}

// create a table containing all the decoded images for a satellite pass
std::string files(std::string safeSatName, long passStart) {
	std::string table = "";
	try {
		table += "<table>\n";
		auto files = file_list(safeSatName, passStart);
		// 'files' returmed is a list of original images. We may want to 
		// present a thumbnail (if it exists)

		table += make_header_row("Images");
		std::string td, thumb;
		std::filesystem::path thumb_path;
		for (auto & elem : files) {
			thumb = elem; // make copy of image path

			// convert real image path to URI
			elem.replace(elem.find("www/img"), 7, "image");
			td = elem + "<br>";

			// modify real path to look for thumbnail, and do so...
			thumb.replace(thumb.find("img"), 3, "img/thumb");
			thumb_path = thumb;
			if (std::filesystem::exists(thumb_path)) {

				// convert thumbnail real path to URI
				thumb.replace(thumb.find("www/img/thumb"), 13, "thumb");

				// presnt the thumbnail and a link to the big image
				td += "<a href=\"" + elem + "\">";
				td += "<img src=\"" + thumb + "\">";
				td += "</a>";
			}
			else {
				// no thumbnail so presnt the original image
				td += "<img src=\"" + elem + "\">";
			}
			table += make_row(td);
		}
		table += "</table>\n";
	}
	catch (Exception const & e) {
		printf("%s (%d)\n", e.Message.c_str(), e.Result);
	}
	return table;
}

// convert the satellite name in DB to the value used in file names
std::string make_safe(std::string in) {
	std::string out = in;
	std::replace(out.begin(), out.end(), ' ', '_');
	std::erase(out, '(');
			std::erase(out, '}');
			return out;
			}

			// display the sattelite pass schedule
			std::string passes() {
			std::string table = "";
			try {
			Connection connection = Connection(db);

			Statement statement(connection, "SELECT sat_name, DATE(pass_start, 'unixepoch', 'localtime'), TIME(pass_start, 'unixepoch', 'localtime'), TIME(pass_end, 'unixepoch', 'localtime'), max_elev, direction, azimuth_at_max, device, signal_type, status, pass_start, rowid FROM TRANSITS ORDER BY pass_start DESC");

			table += "<table>\n";
			table += make_header_row("Satellite Name", "Pass Start<br>(" + utc_delta_s + ")", "Pass End<br>(" + utc_delta_s + ")", "Max.<br>Elevation" , "Image<br>Count", "");
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

			std::string cnt = "";
			std::string lnk = "";
			if (std::string(pass.GetString(9)) == "complete") {
				if (files.size()) {
					cnt = "<a href=\"files?sat-name=" + safeSatName + "&start=" + pass.GetString(10) + "\">" + std::to_string(files.size()) + "</a>";
				}
				else {
					cnt = "0";
				}
				lnk += std::string("<img class=\"icon\"") + 
					" src=\"./listen-icon.png\"" +
					" onclick=\"playWav(this, '/home/pi/SatTrack/wav/" + 
					root_name(safeSatName, std::atol(pass.GetString(10))) +
					".wav')\" alt=\"listen\">";
			}
			else {
				// this must be a 'future' pass, so offer a delete option
				// (we will check the status again in case it's too late)
				lnk += std::string("<a href=\"pass_del?pass_row=") + 
					pass.GetString(11) + 
					"\"><img class=\"icon\" src=\"./delete-icon.png\"" +
					" alt=\"delete\"></a>";
			}

			table += make_row(pass.GetString(0), // sat_name
					pass.GetString(2),          // time-start
					pass.GetString(3),          // time-end
					elev,                       // max. elev.
								    // pass.GetString(6),          // azimuth @ max.
								    // pass.GetString(5),          // dir
					cnt,                        // extracted file count
					lnk);
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

	utc_delta_s = utc_delta();
	httplib::Server svr;
	auto ret = svr.set_mount_point("/", "/home/pi/SatTrack/www"); // everything in here is
								      // served by default
	if (!ret) {
		std::cout << "Cannot locate /home/pi/SatTrack/www" << std::endl;
		exit(0);
	}

	// default to the pass schedule
	svr.Get("/", [](const httplib::Request& /* req */, httplib::Response& res) {
			res.set_redirect("./passes");
			});

	svr.Get("/passes", [](const httplib::Request& /* req */, httplib::Response& res) {
			std::string body = getTemplate("/home/pi/SatTrack/www/html_template");
			body.replace(body.find("{{}}"), 4, passes());
			res.set_content(body.c_str(), "text/html");
			});

	svr.Get("/sat_add", [](const httplib::Request& /* req */, httplib::Response& res) {
			std::string form = getTemplate("/home/pi/SatTrack/www/add_template");
			form.replace(form.find("{{}}"), 4, satellite_opts());
			std::string body = getTemplate("/home/pi/SatTrack/www/html_template");
			body.replace(body.find("{{}}"), 4, form);
			res.set_content(body.c_str(), "text/html");
			});

	svr.Get("/sat_del", [](const httplib::Request& req, httplib::Response& res) {
			if (req.params.find("sat_row") != req.params.end()) {
			sat_del(req.params.find("sat_row")->second);
			}
			res.set_redirect("./satellites");
			});

	svr.Get("/pass_del", [](const httplib::Request& req, httplib::Response& res) {
			if (req.params.find("pass_row") != req.params.end()) {
			pass_del(req.params.find("pass_row")->second);
			}
			res.set_redirect("./passes");
			});

	svr.Post("/sat_save", [](const httplib::Request& req, httplib::Response& res) {
			sat_save(req.params);
			res.set_redirect("./satellites");
			});

	svr.Get("/sat_edit", [](const httplib::Request& req, httplib::Response& res) {
			if (req.params.find("sat_row") != req.params.end()) {
			std::string form = sat_edit(req.params.find("sat_row")->second);
			std::string body = getTemplate("/home/pi/SatTrack/www/html_template");
			body.replace(body.find("{{}}"), 4, form);
			res.set_content(body.c_str(), "text/html");
			}
			else {
			res.set_redirect("./satellites");
			}
			});

	svr.Get("/files", [](const httplib::Request& req, httplib::Response& res) {
			std::string body = getTemplate("/home/pi/SatTrack/www/html_template");
			std::string insert = files(req.get_param_value("sat-name"), 
					std::atol(req.get_param_value("start").c_str()));
			body.replace(body.find("{{}}"), 4, insert);
			res.set_content(body.c_str(), "text/html");
			});

	svr.Get("/satellites", [](const httplib::Request& /* req */, httplib::Response& res) {
			std::string body = getTemplate("/home/pi/SatTrack/www/html_template");
			body.replace(body.find("{{}}"), 4, satellites());
			res.set_content(body.c_str(), "text/html");
			});

	svr.Get("/thumb/:id", [&](const httplib::Request& req, httplib::Response& res){
			auto id = req.path_params.at("id");
			std::ifstream in(image_dir + "thumb/" + id, std::ios::in | std::ios::binary);
			if(in){
			std::ostringstream contents;
			contents << in.rdbuf();
			in.close();
			if (id.find(".bmp") != std::string::npos)
			res.set_content(contents.str(), "image/bmp");
			else
			res.set_content(contents.str(), "image/png");
			}else{
			std::cout << "Not Found! - " << image_dir + "thumb/" + id << std::endl;
			res.status = 404;
			}
			});

	svr.Get("/image/:id", [&](const httplib::Request& req, httplib::Response& res){
			auto id = req.path_params.at("id");
			std::ifstream in(image_dir + id, std::ios::in | std::ios::binary);
			if(in){
			std::ostringstream contents;
			contents << in.rdbuf();
			in.close();
			if (id.find(".bmp") != std::string::npos)
			res.set_content(contents.str(), "image/bmp");
			else
			res.set_content(contents.str(), "image/png");
			}else{
			std::cout << "Not Found! - " << image_dir + id << std::endl;
			res.status = 404;
			}
			});

	svr.Get("/wav/:id", [&](const httplib::Request& req, httplib::Response& res){
			auto id = req.path_params.at("id");
			std::ifstream in(wav_dir + id, std::ios::in | std::ios::binary);
			if(in){
			std::ostringstream contents;
			contents << in.rdbuf();
			in.close();
			res.set_content(contents.str(), "audio/wav");
			}else{
			std::cout << "Not Found! - " << wav_dir + id << std::endl;
			res.status = 404;
			}
			});

	// for now just ignoring unknown URLs

	svr.listen("0.0.0.0", port);
}
