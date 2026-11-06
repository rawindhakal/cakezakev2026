import { useState } from 'react';
import {
    Dialog,
    DialogContent, DialogHeader
} from "@/components/ui/dialog";
import LightBox from '@/components/ui/LightBox';
import type { Slide } from 'yet-another-react-lightbox';
import { t } from '@/utils/translation';
import ImageWithPlaceholder from '../image-with-placeholder/ImageWithPlaceholder';

interface RatingImagesModalProps {
    showImagesModal: boolean;
    setShowImagesModal: (show: boolean) => void;
    // Rating images list
    images?: any[];
}

const RatingImagesModal = ({ showImagesModal, setShowImagesModal, images }: RatingImagesModalProps) => {

    const [showLightBox, setShowLightBox] = useState(false)
    const [imageIndex, setImageIndex] = useState(0)
    const [lightBoxImages, setLightBoxImages] = useState<Slide[]>([])

    const handleLightBox = (index: number) => {
        const ratingImages = images?.map((img) => ({ src: img?.src ? img?.src : img }))
        setLightBoxImages(ratingImages ?? [])
        setImageIndex(index)
        setShowLightBox(true)
    }

    return (
        <div>
            <Dialog open={showImagesModal} onOpenChange={setShowImagesModal}>

                <DialogContent title={t("Rating_images")}>
                    <DialogHeader>
                        <h1 className='font-bold text-2xl'>{t("Rating_images")}</h1>
                    </DialogHeader>
                    <div className='flex flex-wrap gap-2 justify-center'>
                        {images?.map((image, index) => {
                            return (
                                <div className="relative w-24 h-24 rounded overflow-hidden" key={image?.src ?? image}>
                                    {/* Rating image thumbnail */}
                                    <ImageWithPlaceholder
                                        src={image}
                                        alt="Rating image"
                                        width={96}
                                        height={96}
                                        sizes="96px"
                                        quality={75}
                                        className="h-full w-full object-cover"
                                        {...({ loading: "lazy", onClick: () => handleLightBox(index) } as any)}
                                    /></div>
                            )
                        })}
                    </div>
                </DialogContent>
            </Dialog>
            <LightBox
                showLightBox={showLightBox}
                setShowLightbox={setShowLightBox}
                images={lightBoxImages}
                imageIndex={imageIndex}
            />
        </div>
    )
}


export default RatingImagesModal
