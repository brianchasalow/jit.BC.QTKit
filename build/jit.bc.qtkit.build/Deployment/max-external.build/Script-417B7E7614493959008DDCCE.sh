#!/bin/sh
rm -r -f "/Applications/Max6/externals/$PRODUCT_NAME.mxo"
cp -f -r "$TARGET_BUILD_DIR/$PRODUCT_NAME.mxo" "/Applications/Max6/externals/$PRODUCT_NAME.mxo"

rm -r -f "$TARGET_BUILD_DIR/../examples/$PRODUCT_NAME/$PRODUCT_NAME.mxo"
cp -f -r "$TARGET_BUILD_DIR/$PRODUCT_NAME.mxo" "$TARGET_BUILD_DIR/../examples/$PRODUCT_NAME/$PRODUCT_NAME.mxo"
