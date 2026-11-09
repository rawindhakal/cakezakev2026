import React, { useEffect } from 'react'
import { useSelector } from 'react-redux'
import HomeOfferModal from '../homepageoffermodal/HomeOfferModal'
import Loader from '../loader/Loader'
import HomeLayout from '../homelayout/HomeLayout'
import useIsHydrated from '@/hooks/useIsHydrated'

interface HomePageProps {
    initialHomeLayout?: any
    heading?: string | null
}

const HomePage = ({ initialHomeLayout = null, heading = null }: HomePageProps) => {

    const setting = useSelector((state: any) => state.Setting)
    const language = useSelector((state: any) => state.Language.selectedLanguage)
    const hydrated = useIsHydrated()

    useEffect(() => { }, [language?.id])

    // Show skeleton if settings and layout payload are missing after hydration
    const showSkeleton = hydrated
        ? setting?.setting == null && !initialHomeLayout
        : !initialHomeLayout;

    return (
        <>
            <div>
                {/* Hidden H1 for SEO */}
                {heading && <h1 className="sr-only">{heading}</h1>}
                {/* Full screen loader */}
                {showSkeleton ? <Loader screen="full" /> :
                    <>
                        <HomeLayout initialHomeLayout={initialHomeLayout} />
                        {/* Offer modal for hydrated clients */}
                        {hydrated && setting?.setting && setting?.setting?.popup_enabled === "1" &&
                            <HomeOfferModal />
                        }
                    </>
                }
            </div>
        </>
    )
}

export default HomePage