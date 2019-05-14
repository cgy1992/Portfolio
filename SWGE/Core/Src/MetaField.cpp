#include "Precompiled.h"
#include "MetaType.h"
#include "MetaField.h"

using namespace SWGE;
using namespace Core;

MetaField::MetaField(const char* const name, const MetaType* const type, size_t offset)
	: mName(name)
	, mType(type)
	, mOffset(offset)
{

}