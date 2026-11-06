"use client";

import React, { useEffect } from 'react'
import ProductDescription from '../productdetail/ProductDetail'
import { useSelector } from 'react-redux'

const ProductDescriptionPage = ({ initialProduct, initialProductMeta }: any) => {
    const language = useSelector((state: any) => state.Language.selectedLanguage)

    useEffect(() => { }, [language?.id])
    return (
        <ProductDescription
            initialProduct={initialProduct}
            initialProductMeta={initialProductMeta}
        />
    )
}

export default ProductDescriptionPage