#! /bin/bash

. ${IOTDIN_LIB_HOME}/eeprom_layout_0x11.inc

export PAGE_SIZE=128
export FIRST_PAGE_NUM=1
export LAST_PAGE_NUM=1
export DEFAULT_PAGE_NUM=${FIRST_PAGE_NUM}

############################################################################
# eeprom_init()	- initializes an empty ${EEPROM_FILE} and ${EEPROM_CHECK} files
# 		  and clears the eeprom chip
# @eeprom_dev:	- path to the eeprom device file, if not set a pre-defined path is used
# @page:	- eeprom page num, if not set a pre-defined default page number is used
# @file:	- path to the file, if not set a pre-defined path is used
# @erase_mode:	- erase mode ((1) - 0xff, (0) - 0x00), if not set, the 0xff mode is assumed
############################################################################
function eeprom_init() {
	ebegin "Clearing system EEPROM"

	local EEPROM=${1:-${EEPROM_DEV}}
	local PAGE=${2:-${DEFAULT_PAGE_NUM}}
	local FILE=${3:-${EEPROM_FILE}}
	local ERASE_MODE=${4:-1}

	# clear EEPROM_FILE
	if [[ ${ERASE_MODE} -eq 1 ]]; then
		# write all 0xff
		dd if=/dev/zero count=1 bs=${PAGE_SIZE} | tr '\000' '\377' > ${FILE}
	else
		dd if=/dev/zero count=1 bs=${PAGE_SIZE} of=${FILE} conv=fsync
	fi

	#eeprom_write_file ${EEPROM} ${FILE} ${PAGE} || return 1
	#eeprom_check ${EEPROM} ${FILE} ${PAGE} || return 1

	eend 0;
	return 0;
}

############################################################################
# eeprom_finalize()	- actually writes the data to the eeprom chip
#
# @eeprom_dev:	- path to the eeprom device file, if not set a pre-defined path is used
# @page: - eeprom page num, if not set a pre-defined default page number is used
# @file:	- path to the file, if not set a pre-defined path is used
############################################################################
function eeprom_finalize() {
	ebegin "Writing system EEPROM"

	local EEPROM=${1:-${EEPROM_DEV}}
	local PAGE=${2:-${DEFAULT_PAGE_NUM}}
	local FILE=${3:-${EEPROM_FILE}}

	local layout=$(eeprom_get_layout_version ${FILE} ${PAGE})

	# check that the layout value is not trivial
	if [[ ${layout} -le 0 || ${layout} -ge 255 ]]; then
		layout=${EEPROM_LAYOUT_VERSION}
		eeprom_set_layout_version ${EEPROM_LAYOUT_VERSION} ${FILE} ${PAGE} || return 1;
	fi

	info_msg "Using EEPROM layout version: ${layout}"

	if [ ${layout} -gt 2 ]; then
		eeprom_set_compulab_id || return 1;
	fi

	eeprom_write_file ${EEPROM} ${FILE} ${PAGE} || return 1
	eeprom_check ${EEPROM} ${FILE} ${PAGE} || return 1

	eend 0;
	return 0;
}

############################################################################
# eeprom_write_file()	- writes a file to eeprom chip
#
# @eeprom_dev:	- path to the eeprom device file, if not set a pre-defined path is used
# @file:	- path to the file, if not set a pre-defined path is used
# @page: - eeprom page num, if not set, a pre-defined default page number is used
############################################################################
function eeprom_write_file() {
	local EEPROM=${1:-${EEPROM_DEV}}
	local FILE=${2:-${EEPROM_FILE}}
	local PAGE=${3:-${DEFAULT_PAGE_NUM}}
	local SEEK=$((PAGE-1))

	dd if=${FILE} of=${EEPROM} obs=${PAGE_SIZE} seek=${SEEK} bs=${PAGE_SIZE} count=1 conv=notrunc &>/dev/null
	if [ $? -ne 0 ]; then
		bad_msg "EEPROM: could not write to the eeprom chip!";
		return 1;
	fi
}

############################################################################
# eeprom_read_to_file()	- read eeprom specific page and put into a file
#
# @eeprom_dev:	- path to the eeprom device file, if not set a pre-defined path is used
# @file:	- path to the file, if not set a pre-defined path is used
# @page: - eeprom page num, if not set, a pre-defined default page number is used
############################################################################
function eeprom_read_to_file() {
	local EEPROM=${1:-${EEPROM_DEV}}
	local FILE=${2:-${EEPROM_FILE}}
	local PAGE=${3:-${DEFAULT_PAGE_NUM}}
	local SKIP=$((PAGE-1))

	dd if=${EEPROM} of=${FILE} skip=${SKIP} bs=${PAGE_SIZE} count=1 &>/dev/null
	if [ $? -ne 0 ]; then
		bad_msg "EEPROM: could not read from the ${EEPROM} device, page ${PAGE}!";
		return 1;
	fi
}

############################################################################
# eeprom_check()	- checks the data written to the eeprom chip by comparing
#						to a source file
#
# @eeprom_dev:	- path to the eeprom device file, if not set a pre-defined path is used
# @source:	- path to the source file, if not set a pre-defined path is used
# @page: - eeprom page num, if not set a pre-defined default page number is used
# @checkfile: - path to the check file, if not set a pre-defined path is used
# @erase_mode:	- erase mode ((1) - 0xff, (0) - 0x00), if not set, the 0xff mode is assumed
############################################################################
function eeprom_check() {
	local EEPROM=${1:-${EEPROM_DEV}}
	local FILE=${2:-${EEPROM_FILE}}
	local PAGE=${3:-${DEFAULT_PAGE_NUM}}
	local SKIP=$((PAGE-1))
	local REF_FILE=${4:-${EEPROM_CHECK}}
	local ERASE_MODE=${5:-1}

	# Clear REF_FILE
	if [[ ${ERASE_MODE} -eq 1 ]]; then
		# write all 0xff
		dd if=/dev/zero count=1 bs=${PAGE_SIZE} | tr '\000' '\377' > ${REF_FILE}
	else
		dd if=/dev/zero count=1 bs=${PAGE_SIZE} of=${REF_FILE}
	fi

	# read the data from EEPROM and check
	dd if=${EEPROM} of=${REF_FILE} ibs=${PAGE_SIZE} skip=${SKIP} bs=${PAGE_SIZE} count=1 > /dev/null 2>&1 || return 1
	diff ${FILE} ${REF_FILE}
	if [ $? -ne 0 ]; then
		bad_msg "EEPROM: data check failed!";
		return 1;
	fi
}

############################################################################
# eeprom_set_revision_major() - sets the major revision number
#
# @revision:	- the major revision decimal number.
#		  Current maximal value 2^16 - 1.
# @page:	- eeprom page num, if not set a pre-defined default page number is used
# @file:	- path to the file, if not set a pre-defined path is used
############################################################################
function eeprom_set_revision_major() {
	local PAGE=${2:-${DEFAULT_PAGE_NUM}}
	local FILE=${3:-${EEPROM_FILE}}
	eeprom_set_revision "major" ${1} ${PAGE} ${FILE};
	return $?;
}

############################################################################
# eeprom_set_revision()	- sets the revision number
#
# @rev_type:	- flag specifying the revision type: <major>
# @revision:	- the revision decimal number. Current maximal value 2^16 - 1.
# @page:	- eeprom page num, if not set a pre-defined default page number is used
# @file:	- path to the file, if not set a pre-defined path is used
############################################################################
function eeprom_set_revision() {
	local REVTYPE=${1} # unused
	local REV=${2}
	local PAGE=${3:-${DEFAULT_PAGE_NUM}}
	local FILE=${4:-${EEPROM_FILE}}
	local REV0=$REV
	local REV1=0
	local SEEK=$(((PAGE-1) * PAGE_SIZE + EEPROM_REVISION_OFFSET))

	local data=""
	declare -i digit=16#ff

	((REV0 = REV & 0xff))
	((REV1 = REV >> 0x8))

	digit=10#`echo ${REV0}`
	data=`printf "\\%04o" ${digit}`
	digit=10#`echo $REV1`
	data=${data}`printf "\\%04o" ${digit}`

	# write the revision to the buffer file
	echo -ne ${data} | dd conv=notrunc of=${FILE} bs=1 count=2 seek=${SEEK} > /dev/null 2>&1 || return 1

	return 0;
}

#############################################################################
# void eeprom_print_board_revision(char *eeprom_dev) - Prints the revision field 
#														as it appears in eeprom.
#
# @eeprom_dev:	- path to the eeprom device file, if not set a pre-defined path is used
# @page:	- eeprom page num, if not set a pre-defined default page number is used
#############################################################################
function eeprom_print_board_revision() {
	local EEPROM=${1:-${EEPROM_DEV}}
	local PAGE=${2:-${DEFAULT_PAGE_NUM}}
	local PAGE_OFFSET=$(((PAGE-1)*PAGE_SIZE))

	# The revision field size is always 2 bytes
	hexdump -s $((PAGE_OFFSET+EEPROM_REVISION_OFFSET)) -n 2 -e '/2 "%d\n"' ${EEPROM}
}

############################################################################
# eeprom_set_hex_value() - sets a hex value of a given length,
#                          the MSB is written on the lower address
#
# @value:	- the hexval to be written
# @length	- the value length in bytes (up to 16)
# @offset	- required offset
# @page:	- eeprom page num, if not set a pre-defined default page number is used
# @file:	- path to the file, if not set a pre-defined path is used
############################################################################
function eeprom_set_hex_value() {
	declare -i VAL=${1}
	local LEN=${2}
	local OFFSET=${3}
	local PAGE=${4:-${DEFAULT_PAGE_NUM}}
	local PAGE_OFFSET=$(((PAGE-1)*PAGE_SIZE))
	local FILE=${5:-${EEPROM_FILE}}

	[[ ${LEN} -gt 16 ]] && LEN=16
	L=$((LEN*2))
	# Convert to binary value
	local BIN_VAL=$(printf "%0$((LEN*2))x\n" "${VAL}" | sed 's/../\\x&/g')
	# Write the binary value
	printf "${BIN_VAL}" | dd conv=notrunc of=${FILE} bs=1 seek=$((PAGE_OFFSET+OFFSET)) > /dev/null 2>&1 || return 1

	return 0;
}

############################################################################
# eeprom_set_ifm_id() - sets RESOURCE_MAP hex value of a given IFM type
#
# @type:	- the IFM type: <RS485 | RS232 | DI8O8 | ADC8> 
# @page:	- eeprom page num, if not set a pre-defined default page number is used
# @file:	- path to the file, if not set a pre-defined path is used
############################################################################
function eeprom_set_res_map() {
	local TYPE=${1}
	local PAGE=${2:-${DEFAULT_PAGE_NUM}}
	local FILE=${3:-${EEPROM_FILE}}

	if [[ "${IFM_TYPE[@]}" =~ "${TYPE}" ]]; then
		local RMAP="RMAP_""${TYPE}"
	else
		return 1;
	fi

	eeprom_set_hex_value ${RMAP} ${EEPROM_RESOURCE_MAP_LEN} ${EEPROM_RESOURCE_MAP_OFFSET}

	return $?;
}

############################################################################
# eeprom_set_ifm_id() - sets IFM_ID hex value of a given IFM type
#
# @type:	- the IFM type: <RS485 | RS232 | DI8O8 | ADC8> 
# @page:	- eeprom page num, if not set a pre-defined default page number is used
# @file:	- path to the file, if not set a pre-defined path is used
############################################################################
function eeprom_set_ifm_id() {
	local TYPE=${1}
	local PAGE=${2:-${DEFAULT_PAGE_NUM}}
	local FILE=${3:-${EEPROM_FILE}}

	if [[ "${IFM_TYPE[@]}" =~ "${TYPE}" ]]; then
		local IFM_ID="IFM_ID_""${TYPE}"
	else
		return 1;
	fi

	eeprom_set_hex_value ${IFM_ID} ${EEPROM_IFM_ID_LEN} ${EEPROM_IFM_ID_OFFSET}

	return $?;
}

############################################################################
# eeprom_print_hex_value() - prints a string represening a hex value of a given
#                            length from a specified offset
# @offset	- required offset
# @length	- the value length in bytes (up to 16)
# @page:	- eeprom page num, if not set a pre-defined default page number is used
# @file:	- path to the file, if not set a pre-defined path is used
############################################################################
function eeprom_print_hex_value() {
	local OFFSET=${1}
	local LEN=${2}
	local PAGE=${3:-${DEFAULT_PAGE_NUM}}
	local PAGE_OFFSET=$(((PAGE-1)*PAGE_SIZE))
	local FILE=${4:-${EEPROM_FILE}}

	# Make sure the file exists
	[[ -e ${FILE} ]] || return 1

	[[ ${LEN} -gt 16 ]] && LEN=16
	# Dump value to an ASCII string
	local VAL=$(dd if=${FILE} bs=1 skip=$((PAGE_OFFSET+OFFSET)) count=${LEN} 2>/dev/null | od -An -tx1 | tr -d ' \n')
	echo ${VAL};
}

############################################################################
# eeprom_print_res_map() - prints a string represening RESOURCE_MAP
#
# @page:	- eeprom page num, if not set a pre-defined default page number is used
# @file:	- path to the file, if not set a pre-defined path is used
############################################################################
function eeprom_print_res_map() {
	local PAGE=${1:-${DEFAULT_PAGE_NUM}}
	local PAGE_OFFSET=$(((PAGE-1)*PAGE_SIZE))
	local FILE=${2:-${EEPROM_FILE}}

	eeprom_print_hex_value ${EEPROM_RESOURCE_MAP_OFFSET} ${EEPROM_RESOURCE_MAP_LEN} ${PAGE} ${FILE}
}

############################################################################
# eeprom_print_ifm_id() - prints a string represening IFM_ID
#
# @page:	- eeprom page num, if not set a pre-defined default page number is used
# @file:	- path to the file, if not set a pre-defined path is used
############################################################################
function eeprom_print_ifm_id() {
	local PAGE=${1:-${DEFAULT_PAGE_NUM}}
	local PAGE_OFFSET=$(((PAGE-1)*PAGE_SIZE))
	local FILE=${2:-${EEPROM_FILE}}

	eeprom_print_hex_value ${EEPROM_IFM_ID_OFFSET} ${EEPROM_IFM_ID_LEN} ${PAGE} ${FILE}
}

############################################################################
# eeprom_set_serial_number()	- sets the serial number of the board
#
# @serial:	- serial number string. Current assumption that the serial
#		  number is a string of hex digits (12 bytes maximal length)
# @file:	- path to the file, if not set a pre-defined path is used
# @page:	- eeprom page num, if not set a pre-defined default page number is used
############################################################################
function eeprom_set_serial_number() {
	local SERIAL=${1}
	local FILE=${2:-${EEPROM_FILE}}
	local PAGE=${3:-${DEFAULT_PAGE_NUM}}
	local data=""
	declare -i digit=16#ff
	local padding="";

	SERIAL=`echo ${SERIAL} | tr '-' '0'`
	# if the serial number is less then 12 bytes (24 hex digits), pad it with zeros
	for ((i=0; i<$((24-${#SERIAL})); i++)); do
		padding=0${padding};
	done;
	SERIAL=${padding}${SERIAL};

	for ((i=1; i<=12; i++)); do
		digit=16#`echo ${SERIAL} | cut -c$((i*2-1))-$((i*2))`
		# all EEPROM layout standards have the MSB in the higher addresses
		# and LSB in lower addresses. Therefore the data is appended at the end.
		data=`printf "\\%04o" ${digit}`${data}
	done

	# write the serial number to the buffer file
	echo -ne ${data} | dd conv=notrunc of=${FILE} bs=1 count=12 seek=${EEPROM_SERIAL_NUM_OFFSET} > /dev/null 2>&1 || return 1

	return 0;
}

############################################################################
# int eeprom_get_serial_number(void) - gets the serial number of the board
#
# @page: - eeprom page num, if not set a pre-defined default page number is used
# @eeprom_dev:	- path to the eeprom device file, if not set a pre-defined path is used
#
# Sets the global EEPROM_SERIAL
# Returns 0.
############################################################################
function eeprom_get_serial_number() {
	local PAGE=${1:-${DEFAULT_PAGE_NUM}}
	local PAGE_OFFSET=$(((PAGE-1)*PAGE_SIZE))
	local EEPROM=${2:-${EEPROM_DEV}}

	# Get the serial number value from the EEPROM
	local serial=`hexdump -x -s $((PAGE_OFFSET+EEPROM_SERIAL_NUM_OFFSET)) -n 12 ${EEPROM} | grep "0000.14" | cut -d' ' -f2-`

	# Convert the serial number to string
	EEPROM_SERIAL=
	for i in {6..1}; do
		EEPROM_SERIAL=${EEPROM_SERIAL}`echo $serial | cut -d' ' -f${i}`
	done

	# Remove leading zeros
	EEPROM_SERIAL=`echo ${EEPROM_SERIAL} | sed 's/^0*//'`

	return 0;
}

############################################################################
# eeprom_set_layout_version()	- sets the version of the eeprom layout
#
# @version:	- the version number
# @file:	- path to the file, if not set a pre-defined path is used
# @page:	- eeprom page num, if not set a pre-defined default page number is used
############################################################################
function eeprom_set_layout_version() {
	local LAYOUT=${1}
	local FILE=${2:-${EEPROM_FILE}}
	local PAGE=${3:-${DEFAULT_PAGE_NUM}}
	local SEEK=$(((PAGE-1) * PAGE_SIZE + EEPROM_LAYOUT_VER_OFFSET))

	local data=""
	declare -i digit=16#ff

	digit=10#${LAYOUT}
	data=`printf "\\%04o" $digit`

	# write the eeprom layout version to the buffer file
	echo -ne ${data} | dd conv=notrunc of=${FILE} bs=1 count=1 seek=${SEEK} > /dev/null 2>&1 || return 1

	return 0;
}

############################################################################
# eeprom_get_layout_version()	- return the layout version set in the file
# @file:	- path to the file, if not set a pre-defined path is used
# @page:	- eeprom page num, if not set a pre-defined default page number is used
############################################################################
function eeprom_get_layout_version() {
	local FILE=${1:-${EEPROM_FILE}}
	local PAGE=${2:-${DEFAULT_PAGE_NUM}}
	local SKIP=$(((PAGE-1) * PAGE_SIZE + EEPROM_LAYOUT_VER_OFFSET))

	eeprom_print_hex_value ${EEPROM_LAYOUT_VER_OFFSET} 1 ${PAGE} ${FILE}
}

############################################################################
# eeprom_set_compulab_id()	- sets the compulab id
#
# @file:	- path to the file, if not set a pre-defined path is used
# @page:	- eeprom page num, if not set a pre-defined default page number is used
# Note:	this function __should not__ be called from out side this file.
############################################################################
function eeprom_set_compulab_id() {
	local EEPROM_COMPULAB_ID="CLE"
	local FILE=${1:-${EEPROM_FILE}}
	local PAGE=${2:-${DEFAULT_PAGE_NUM}}
	local SEEK=$(((PAGE-1) * PAGE_SIZE + EEPROM_COMPULAB_ID_OFFSET))

	declare -i digit=16#ff
	local data=""

	for ((i=0; i<3; i++)); do
		digit=10#`printf "%d" "'${EEPROM_COMPULAB_ID:$i:1}"`
		data=${data}`printf "\\%04o" ${digit}`
	done

	echo -ne ${data} | dd conv=notrunc of=${FILE} bs=1 count=3 seek=${SEEK} > /dev/null 2>&1 || return 1;
}

############################################################################
# eeprom_set_mac_offset()	- sets the eeprom offset of the mac address
#
# @type:	- the type of the offset: <first|second|wifi|wlan|bt>
############################################################################
function eeprom_set_mac_offset() {
	case "${1}" in
		"first" | "wifi" | "wlan")
			export EEPROM_MAC_OFFSET=${EEPROM_FIRST_MAC_OFFSET}
			;;
		"second" | "bt")
			export EEPROM_MAC_OFFSET=${EEPROM_SECOND_MAC_OFFSET}
			;;
		*)
			return 1;
	esac

	return 0;
}

############################################################################
# eeprom_get_mac_address()	- gets any mac address
# @page: - eeprom page num, if not set a pre-defined default page number is used
#
# Gets
# @mac_type:	- the type of the mac address: <first|second|wifi|bt>
# Sets the global ETH_MAC
############################################################################
function eeprom_get_mac_address() {
	local MACTYPE=${1}
	local MAC
	local FILE=${2:-${EEPROM_FILE}}
	local PAGE=${3:-${DEFAULT_PAGE_NUM}}

	eeprom_set_mac_offset ${MACTYPE} || return 1;
	local OFFSET=$(((PAGE-1) * PAGE_SIZE + EEPROM_MAC_OFFSET))

	MAC=`hexdump -x -s $((PAGE_OFFSET+EEPROM_MAC_OFFSET)) -n 6 ${FILE} | head -1 | cut -d\  -f2-`
	ETH_MAC=`echo ${MAC} | sed 's/\(..\)\(..\) \(..\)\(..\) \(..\)\(..\)/\2:\1:\4:\3:\6:\5/'`
	export ETH_MAC

	return 0;
}

############################################################################
# eeprom_set_mac_address()	- sets any mac address
#
# @mac_type:	- the type of the mac address: <first|second|wifi|bt>
# @mac:		- mac address string delimited with ":"
#		  example: "00:01:02:03:04:05"
############################################################################
function eeprom_set_mac_address() {
	local MACTYPE=${1}
	local MAC=${2}
	local FILE=${3:-${EEPROM_FILE}}
	local PAGE=${4:-${DEFAULT_PAGE_NUM}}
	local data=""
	declare -i digit=16#ff

	eeprom_set_mac_offset ${MACTYPE} || return 1;
	local SEEK=$(((PAGE-1) * PAGE_SIZE + EEPROM_MAC_OFFSET))

	for ((i=1; i<=6; i++)); do
		digit=16#`echo ${MAC} | cut -d: -f${i}`
		data=${data}`printf "\\%04o" ${digit}`
	done

	# write the mac address to the buffer file
	echo -ne ${data} | dd conv=notrunc of=${FILE} bs=1 count=6 seek=${SEEK} > /dev/null 2>&1 || return 1

	return 0;
}

############################################################################
# eeprom_set_prod_date()	- sets the production date as reported by
#							  the date command.
# @file:	- path to the file, if not set a pre-defined path is used
# @page:	- eeprom page num, if not set a pre-defined default page number is used
############################################################################
function eeprom_set_prod_date() {
	local FILE=${1:-${EEPROM_FILE}}
	local PAGE=${2:-${DEFAULT_PAGE_NUM}}

	local data=""
	declare -i digit=16#ff

	digit=10#`date +%d`
	data=`printf "\\%04o" ${digit}`
	digit=10#`date +%m`
	data=${data}`printf "\\%04o" ${digit}`
	digit=10#`echo $(($(date +%Y)&0xff))`
	data=${data}`printf "\\%04o" ${digit}`
	digit=10#`echo $(($(date +%Y)/0xff))`
	data=${data}`printf "\\%04o" ${digit}`

	# write the date to the buffer file
	echo -ne ${data} | dd conv=notrunc of=${FILE} bs=1 count=4 seek=${EEPROM_PROD_DATE_OFFSET} > /dev/null 2>&1 || return 1

	return 0;
}

############################################################################
# eeprom_set_ascii_offset()	- sets the eeprom offset of the ascii strings
#
# @type:	- the type of the offset: <name|opts1|rsvd>
############################################################################
function eeprom_set_ascii_offset() {
	case "${1}" in
		name)
			export EEPROM_STRING_OFFSET=${EEPROM_PROD_NAME_OFFSET};
			;;
		opts1)
			export EEPROM_STRING_OFFSET=${EEPROM_PROD_OPTS1_OFFSET};
			;;
		rsvd)
			export EEPROM_STRING_OFFSET=${EEPROM_RESERVED_ASCII_OFFSET};
			;;
		*)
			return 1;
	esac

	return 0;
}

############################################################################
# eeprom_set_string()	- sets an ascii string
#
# @type:	- the type of the string: <name|opts1|rsvd>
# @string:	- the ascii string (15 characters maximum)
# @file:	- path to the file, if not set a pre-defined path is used
############################################################################
function eeprom_set_string() {
	local STRTYPE=${1}
	local STRING=${2}
	local FILE=${3:-${EEPROM_FILE}}

	local data=""
	declare -i digit=16#ff
	local i=0

	eeprom_set_ascii_offset ${STRTYPE} || return 1;

	for letter in `echo ${STRING} | sed 's/\(.\)/\1 /g'`; do
		# make sure the string does not exceed 15 characters
		if [ ${i} -ge 15 ]; then
			warn_msg "EEPROM: $STRTYPE string exceeds 15 characters limit! Truncated!"
			break
		fi

		digit=10#`printf '%d' "'${letter}"`
		data=$data`printf "\\%04o" ${digit}`
		((i++))
	done

	# Strings should end with "\0"
	digit=10#00
	data=$data`printf "\\%04o" $digit`
	((i++))

	# write the string to the buffer file
	echo -ne ${data} | dd conv=notrunc of=${FILE} bs=1 count=${i} seek=${EEPROM_STRING_OFFSET} > /dev/null 2>&1 || return 1

	return 0;
}

#############################################################################
# int eeprom_print_ascii_field(char *eeprom_dev, int offset)	- print ascii field
#
# @eeprom_dev:	- path to the eeprom device file, if not set a pre-defined path is used
# @offset:	- ascii field offset, if not set use EEPROM_PROD_NAME_OFFSET
# @page: - eeprom page num, if not set a pre-defined default page number is used
#
# Prints the ascii field as it appears in eeprom.
#############################################################################
function eeprom_print_ascii_field() {
	local EEPROM=${1:-${EEPROM_DEV}}
	local OFFSET=${2:-${EEPROM_PROD_NAME_OFFSET}}
	local PAGE=${3:-${DEFAULT_PAGE_NUM}}
	local PAGE_OFFSET=$(((PAGE-1)*PAGE_SIZE))

	# The ascii field size is always 16 bytes (as the page size)
	hexdump -s $((PAGE_OFFSET+OFFSET)) -n 16 -e '16 "%_p" "\n"' ${EEPROM} | cut -d. -f1
}

############################################################################
# eeprom_set_prod_name()	- sets the product name
#
# @name:	- the product name ascii string (15 characters maximum)
# @file:	- path to the file, if not set a pre-defined path is used
############################################################################
function eeprom_set_prod_name() {
	local FILE=${2:-${EEPROM_FILE}}
	eeprom_set_string "name" ${1};
	return $?;
}

#############################################################################
# int eeprom_print_board_name(char *eeprom_dev)	- print the board name
#
# @eeprom_dev:	- path to the eeprom device file, if not set a pre-defined path is used
# @page: - eeprom page num, if not set a pre-defined default page number is used
#
# Prints the board name as it appears in eeprom.
#############################################################################
function eeprom_print_board_name() {
	local EEPROM=${1:-${EEPROM_DEV}}
	local PAGE=${2:-${DEFAULT_PAGE_NUM}}

	eeprom_print_ascii_field ${EEPROM} ${EEPROM_PROD_NAME_OFFSET} ${PAGE}
}

############################################################################
# eeprom_set_prod_opts()	- sets the product options fields
#
# @opts:	- the product options ascii string
# @file:	- path to the file, if not set a pre-defined path is used
############################################################################
function eeprom_set_prod_opts() {
	local OPTS="$1"
	local LEN=${#OPTS}
	local FILE=${2:-${EEPROM_FILE}}

	for ((i = 1; i <= 1; i++)); do
		local POS=$(($((i - 1)) * 15))
		local OPT=${OPTS:$POS:15}
		eeprom_set_string "opts$i" "$OPT" || return $?
	done

	return 0;
}

#############################################################################
# int eeprom_print_prod_opts(char *eeprom_dev)	- print the product options
#
# @eeprom_dev:	- path to the eeprom device file, if not set a pre-defined path is used
# @page: - eeprom page num, if not set a pre-defined default page number is used
#
# Prints the product options from all eeprom product options fields.
#############################################################################
function eeprom_print_prod_opts() {
	local EEPROM=${1:-${EEPROM_DEV}}
	local BOARD_OPTS=""
	local PAGE=${2:-${DEFAULT_PAGE_NUM}}
	local PAGE_OFFSET=$(((PAGE-1)*PAGE_SIZE))

	for ((i=${EEPROM_PROD_OPTS1_OFFSET}; i<=${EEPROM_PROD_OPTS_LAST_OFFSET}; i+=16)); do
		BOARD_OPTS=${BOARD_OPTS}$(eeprom_print_ascii_field ${EEPROM} ${i} ${PAGE})
	done

	echo ${BOARD_OPTS};
}
