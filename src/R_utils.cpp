#include <cpp11.hpp>
#include <cmath>

[[cpp11::register]]
double sum_cpp(cpp11::sexp x) {
    if (TYPEOF(x) != REALSXP) cpp11::stop("Expected a double vector");
    const double* values = REAL_RO(x);
    double output = 0.0;
    for (int i = 0; i < Rf_xlength(x); i++) {
        output += values[i];
    }
    return output;
}

[[cpp11::register]]
double mean_cpp(cpp11::sexp x) {
    if (TYPEOF(x) != REALSXP) cpp11::stop("Expected a double vector");
    const double* values = REAL_RO(x);
    double output = 0.0;
    for (int i = 0; i < Rf_xlength(x); i++) {
        output += values[i];
    }
    return output / Rf_xlength(x);
}

[[cpp11::register]]
double var_cpp(cpp11::sexp x) {
    double mean = mean_cpp(x);
    if (TYPEOF(x) != REALSXP) cpp11::stop("Expected a double vector");
    const double* values = REAL_RO(x);
    double output = 0.0;
    for (int i = 0; i < Rf_xlength(x); i++) {
        output += (values[i] - mean) * (values[i] - mean);
    }
    return output / (Rf_xlength(x) - 1);
}

[[cpp11::register]]
double sd_cpp(cpp11::sexp x) {
    return std::sqrt(var_cpp(x));
}
