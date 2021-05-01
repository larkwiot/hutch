VPATH = parser-tools include src src/Sleigh src/build processors/x86/languages processors/8085/languages

CC       = gcc -ggdb 
CXX      = g++ -ggdb 
CXXFLAGS = -O2 -Wall -Wno-sign-compare -std=c++17
CXXFLAGS_SHARED = -O2 -Wall -Wno-sign-compare -fPIC -std=c++17

PARSER_TOOLS        = parser-tools
BUILD_DIR           = src/build
BUILD_SHARED_DIR    = src/build-shared
SLGH_INCLUDE_DIR    = src/Sleigh/include

SRC_DIR          = src
LIB_DIR          = lib
BIN_DIR          = bin


# Core source files used in all projects
CORE := address  float  globalcontext  opcodes  pcoderaw  space  translate  xml

# Files used for any project that use the sleigh decoder
SLEIGH := context  filemanage  pcodecompile    pcodeparse   semantics   \
          sleigh   sleighbase  slghpatexpress  slghpattern  slghsymbol


HUTCH_LIB_ADDONS := hutch

ALL := sleigh-compile x86.sla 8085.sla libsla.a libsla.so

# BUILD EVERYTHING #############################################################
all: $(ALL)

# Ensure that build-directories are used as dependency only once.
$(ALL): | $(BUILD_DIR) $(BUILD_SHARED_DIR)

examples: all
	$(MAKE) -C examples/example-one

x86.sla: sleigh-compile x86.slaspec
	./bin/sleigh-compile -a processors/x86/languages

8085.sla: sleigh-compile 8085.slaspec
	./bin/sleigh-compile -a processors/8085/languages

# SLEIGH COMPILER ##############################################################
slgh_compile.o: slgh_compile.cc
	$(CXX) $(CXXFLAGS) -I$(SLGH_INCLUDE_DIR) -c $< -o $(BUILD_DIR)/$@

# Parsing + Lexing #############################################################
LEX  = flex
YACC = bison

PARSING_FILES = xml  slghparse  pcodeparse  slghscan

# PARSING ######################################################################
xml.o: xml.cc
	$(CXX) $(CXXFLAGS) -I$(SLGH_INCLUDE_DIR) -c $(BUILD_DIR)/$< -o $(BUILD_DIR)/$@
# For creating shared library.
	$(CXX) $(CXXFLAGS_SHARED) -I$(SLGH_INCLUDE_DIR) -c $(BUILD_DIR)/$< -o \
	$(BUILD_SHARED_DIR)/$(basename $@).cc.o
xml.cc: xml.y
	$(YACC) -p xml -o $(BUILD_DIR)/$@ $<

slghparse.o: slghparse.cc
	$(CXX) $(CXXFLAGS) -I$(SLGH_INCLUDE_DIR) -c $(BUILD_DIR)/$< -o $(BUILD_DIR)/$@
# For creating shared library.
	$(CXX) $(CXXFLAGS_SHARED) -I$(SLGH_INCLUDE_DIR) -c $(BUILD_DIR)/$< -o \
	$(BUILD_SHARED_DIR)/$(basename $@).cc.o

slghparse.cc: slghparse.y
	$(YACC) -d -o $(BUILD_DIR)/$@ $<
	cp $(BUILD_DIR)/slghparse.hh $(BUILD_DIR)/slghparse.tab.hh

pcodeparse.o: pcodeparse.cc
	$(CXX) $(CXXFLAGS) -I$(SLGH_INCLUDE_DIR) -c $(BUILD_DIR)/$< -o $(BUILD_DIR)/$@
# For creating shared library.
	$(CXX) $(CXXFLAGS_SHARED) -I$(SLGH_INCLUDE_DIR) -c $(BUILD_DIR)/$< -o \
	$(BUILD_SHARED_DIR)/$(basename $@).cc.o

pcodeparse.cc: pcodeparse.y
	$(YACC) -p pcode -o $(BUILD_DIR)/$@ $<


# LEXING #######################################################################
slghscan.o: slghscan.cc
	$(CXX) $(CXXFLAGS) -I$(SLGH_INCLUDE_DIR) -c $(BUILD_DIR)/$< -o $(BUILD_DIR)/$@
# For creating shared library.
	$(CXX) $(CXXFLAGS_SHARED) -I$(SLGH_INCLUDE_DIR) -c $(BUILD_DIR)/$< -o \
	$(BUILD_SHARED_DIR)/$(basename $@).cc.o

slghscan.cc: slghscan.l
	$(LEX) -o $(BUILD_DIR)/$@ $<


# RECIPE SHARED ACROSS TARGETS #################################################
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: %.cc
	$(CXX) $(CXXFLAGS) -I$(SLGH_INCLUDE_DIR) -I$(SRC_DIR) -c $< -o $@

# For Hutch addons
$(BUILD_DIR)/%.o: %.cpp
	$(CXX) $(CXXFLAGS) -Iinclude -I$(SLGH_INCLUDE_DIR) -I$(SRC_DIR) -c $< -o $@


# FOR SHARED LIBRARY VERSION ###################################################
$(BUILD_SHARED_DIR):
	mkdir -p $(BUILD_SHARED_DIR)

$(BUILD_SHARED_DIR)/%.cc.o: %.cc
	$(CXX) $(CXXFLAGS_SHARED) -I$(SLGH_INCLUDE_DIR) -I$(SRC_DIR) -c $< -o $@

# For Hutch addons
$(BUILD_SHARED_DIR)/%.cpp.o: %.cpp
	$(CXX) $(CXXFLAGS_SHARED) -Iinclude -I$(SLGH_INCLUDE_DIR) -I$(SRC_DIR) -c $< -o $@



# BUILD SLEIGH COMPILER RECIPE #################################################
# Files specific to the sleigh compiler
SLEIGH_COMP := slgh_compile  slghparse  slghscan

# Collect all the requisite .o files, less the parsing ones. Those are handled
# separately.
SLEIGH_COMP_OBJS := $(addsuffix .o, $(CORE) $(SLEIGH) $(SLEIGH_COMP))

# Creates directories to hold compiled files + build the parsing-related files.
$(SLEIGH_COMP_OBJS): | $(BUILD_DIR) $(BUILD_SHARED_DIR)


sleigh-compile: $(SLEIGH_COMP_OBJS)
	$(CXX) $(CXXFLAGS) -I$(BUILD_DIR) $(BUILD_DIR)/*.o -o $(BIN_DIR)/$@


# BUILD LIBSLA.A RECIPE ########################################################

LIBSLA := loadimage emulate  memstate  opbehavior  slghparse  slghscan

LIBSLA_OBJS := $(addsuffix .o, $(addprefix $(BUILD_DIR)/, \
	$(filter-out $(PARSING_FILES), \
			$(CORE) $(SLEIGH) $(LIBSLA) \
			$(HUTCH_LIB_ADDONS)))) # Add hutch addons to libsla.a

$(LIBSLA_OBJS): | $(BUILD_DIR) $(addsuffix .o, $(PARSING_FILES))
# No actions


# Create static library.
libsla.a: $(LIBSLA_OBJS)
	rm -rf $(LIB_DIR)/$@
	ar rcs $(LIB_DIR)/$@ $^ $(addprefix $(BUILD_DIR)/, xml.o pcodeparse.o)


# BUILD LIBSLA.SO RECIPE #######################################################

LIBSLA_SHARED_OBJS := $(addsuffix .cc.o, $(addprefix $(BUILD_SHARED_DIR)/, \
	$(filter-out $(PARSING_FILES), \
	$(CORE) $(SLEIGH) $(LIBSLA) \
	)))

LIBSLA_SHARED_OBJS += $(addsuffix .cpp.o, $(addprefix $(BUILD_SHARED_DIR)/, \
	$(HUTCH_LIB_ADDONS)))

# Create shared library
libsla.so: $(LIBSLA_SHARED_OBJS)
	$(CXX) -shared -o $(LIB_DIR)/$@ $^ $(addprefix $(BUILD_SHARED_DIR)/, xml.cc.o pcodeparse.cc.o)

# CLEANUP ######################################################################
clean:
	rm -rf src/build
	rm -rf src/build-shared
	rm -f bin/sleigh-compile
	rm -f lib/libsla.a
	rm -f lib/libsla.so
	rm -f processors/x86/languages/x86.sla
	rm -f processors/8085/languages/8085.sla
	rm -f examples/example-one/example-one
	rm -f examples/example-one/*.o


# Useful for debugging. To find out value of variable, type 'make
# print-VARIABLE'
print-%  : ; @echo $* = $($*)


