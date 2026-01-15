# See https://ampl.com/wp-content/uploads/Chapter-9-Specifying-Data-AMPL-Book.pdf

using AMPLDataReader

data = parse_ampl_dat("""
param cost: FRA DET LAN WIN :=
GARY 39 14 11 14
CLEV 27 9 12 9
PITT 24 14 17 13
: STL FRE LAF :=
GARY 16 82 8
CLEV 26 95 17
PITT 28 99 20 ;
"""
)
