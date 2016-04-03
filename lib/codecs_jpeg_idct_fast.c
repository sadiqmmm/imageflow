#include <stdio.h>
#include "imageflow_private.h"
#include "lcms2.h"
#include "codecs.h"

#define JPEG_INTERNALS
#include "libjpeg-turbo_private/jpeglib.h"
#include "libjpeg-turbo_private/jinclude.h"
#include "libjpeg-turbo_private/jconfigint.h" /* Private declarations for DCT subsystem */

//#include "libjpeg-turbo_private/jmorecfg.h" /* Private declarations for DCT subsystem */
#include "libjpeg-turbo_private/jdct.h" /* Private declarations for DCT subsystem */

#include "fastapprox.h"

void jpeg_idct_downscale_wrap_islow_fast(j_decompress_ptr cinfo, jpeg_component_info * compptr, JCOEFPTR coef_block,
                                    JSAMPARRAY output_buf, JDIMENSION output_col);

const float jpeg_scale_to_7_x_7_weights[7][8] = {
    { 0.9039465785026550293, 0.0960534214973449707, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000 },
    { -0.0159397963434457779, 0.8046712279319763184, 0.2112685889005661011, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000 },
    { 0.0000000000000000000, -0.0307929217815399170, 0.6724552512168884277, 0.3583376407623291016, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000 },
    { 0.0000000000000000000, 0.0000000000000000000, -0.0303521882742643356, 0.5303522348403930664, 0.5303522348403930664, -0.0303521882742643356, 0.0000000000000000000, 0.0000000000000000000 },
    { 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.3583376407623291016, 0.6724552512168884277, -0.0307929217815399170, 0.0000000000000000000 },
    { 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.2112685889005661011, 0.8046712279319763184, -0.0159397963434457779 },
    { 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0960534214973449707, 0.9039465785026550293 },
};
const float jpeg_scale_to_6_x_6_weights[6][8] = {
    { 0.7491279840469360352, 0.2508720457553863525, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000 },
    { -0.0224444177001714706, 0.5224443674087524414, 0.5224443674087524414, -0.0224444177001714706, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000 },
    { 0.0000000000000000000, 0.0000000000000000000, 0.2396661937236785889, 0.7156662940979003906, 0.0446674935519695282, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000 },
    { 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0446674935519695282, 0.7156662940979003906, 0.2396661937236785889, 0.0000000000000000000, 0.0000000000000000000 },
    { 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, -0.0224444177001714706, 0.5224443674087524414, 0.5224443674087524414, -0.0224444177001714706 },
    { 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.2508720457553863525, 0.7491279840469360352 },
};
const float jpeg_scale_to_5_x_5_weights[5][8] = {
    { 0.6118828058242797852, 0.4002380371093750000, -0.0121208345517516136, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000 },
    { -0.0219573117792606354, 0.2555175423622131348, 0.6176261901855468750, 0.1488135904073715210, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000 },
    { 0.0000000000000000000, 0.0000000000000000000, 0.0161152519285678864, 0.4838847517967224121, 0.4838847517967224121, 0.0161152519285678864, 0.0000000000000000000, 0.0000000000000000000 },
    { 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.1488135904073715210, 0.6176261901855468750, 0.2555175423622131348, -0.0219573117792606354 },
    { 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, -0.0121208345517516136, 0.4002380371093750000, 0.6118828058242797852 },
};
const float jpeg_scale_to_4_x_4_weights[4][8] = {
    { 0.4553350806236267090, 0.4553350806236267090, 0.0893298164010047913, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000 },
    { 0.0000000000000000000, 0.0820043832063674927, 0.4179956316947937012, 0.4179956316947937012, 0.0820043832063674927, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000 },
    { 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0820043832063674927, 0.4179956316947937012, 0.4179956316947937012, 0.0820043832063674927, 0.0000000000000000000 },
    { 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0893298164010047913, 0.4553350806236267090, 0.4553350806236267090 },
};
const float jpeg_scale_to_3_x_3_weights[3][8] = {
    { 0.3126847147941589355, 0.4027547538280487061, 0.2417637705802917480, 0.0427967458963394165, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000 },
    { 0.0000000000000000000, 0.0095250364392995834, 0.1524054706096649170, 0.3380694985389709473, 0.3380694985389709473, 0.1524054706096649170, 0.0095250364392995834, 0.0000000000000000000 },
    { 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0000000000000000000, 0.0427967458963394165, 0.2417637705802917480, 0.4027547538280487061, 0.3126847147941589355 },
};
const float jpeg_scale_to_2_x_2_weights[2][8] = {
    { 0.1866819113492965698, 0.2613925635814666748, 0.2613925635814666748, 0.1866819113492965698, 0.0875365510582923889, 0.0163145177066326141, 0.0000000000000000000, 0.0000000000000000000 },
    { 0.0000000000000000000, 0.0000000000000000000, 0.0163145177066326141, 0.0875365510582923889, 0.1866819113492965698, 0.2613925635814666748, 0.2613925635814666748, 0.1866819113492965698 },
};
const float jpeg_scale_to_1_x_1_weights[1][8] = {
    { 0.0911070853471755981, 0.1178331747651100159, 0.1392842531204223633, 0.1517754793167114258, 0.1517754793167114258, 0.1392842531204223633, 0.1178331747651100159, 0.0911070853471755981 },
};

const float * weights_by_target[] = {
    &jpeg_scale_to_1_x_1_weights[0][0],
    &jpeg_scale_to_2_x_2_weights[0][0],
    &jpeg_scale_to_3_x_3_weights[0][0],
    &jpeg_scale_to_4_x_4_weights[0][0],
    &jpeg_scale_to_5_x_5_weights[0][0],
    &jpeg_scale_to_6_x_6_weights[0][0],
    &jpeg_scale_to_7_x_7_weights[0][0]

};

const float lut_srgb_to_linear[256] = {
    0.0000000000000000000, 0.0003035269910469651, 0.0006070539820939302, 0.0009105810313485563, 0.0012141079641878605, 0.0015176349552348256, 0.0018211620626971126, 0.0021246890537440777,
    0.0003035269910469651, 0.0009105810313485563, 0.0015176349552348256, 0.0021246890537440777, 0.0027317430358380079, 0.0033465356100350618, 0.0040247170254588127, 0.0047769532538950443,
    0.0006070539820939302, 0.0015176349552348256, 0.0024282159283757210, 0.0033465356100350618, 0.0043914420530200005, 0.0056053916923701763, 0.0069954101927578449, 0.0085681248456239700,
    0.0009105810313485563, 0.0021246890537440777, 0.0033465356100350618, 0.0047769532538950443, 0.0065120910294353962, 0.0085681248456239700, 0.0109600936993956566, 0.0137020805850625038,
    0.0012141079641878605, 0.0027317430358380079, 0.0043914420530200005, 0.0065120910294353962, 0.0091340569779276848, 0.0122864870354533195, 0.0159962922334671021, 0.0202885624021291733,
    0.0015176349552348256, 0.0033465356100350618, 0.0056053916923701763, 0.0085681248456239700, 0.0122864870354533195, 0.0168073754757642746, 0.0221738833934068680, 0.0284260381013154984,
    0.0018211620626971126, 0.0040247170254588127, 0.0069954101927578449, 0.0109600936993956566, 0.0159962922334671021, 0.0221738833934068680, 0.0295568425208330154, 0.0382043756544589996,
    0.0021246890537440777, 0.0047769532538950443, 0.0085681248456239700, 0.0137020805850625038, 0.0202885624021291733, 0.0284260381013154984, 0.0382043756544589996, 0.0497065745294094086,
    0.0024282159283757210, 0.0056053916923701763, 0.0103298230096697807, 0.0168073754757642746, 0.0251868572086095810, 0.0356013253331184387, 0.0481718331575393677, 0.0630100294947624207,
    0.0027317430358380079, 0.0065120910294353962, 0.0122864870354533195, 0.0202885624021291733, 0.0307134501636028290, 0.0437350422143936157, 0.0595112405717372894, 0.0781874284148216248,
    0.0030352699104696512, 0.0074990317225456238, 0.0144438436254858971, 0.0241576302796602249, 0.0368894524872303009, 0.0528606548905372620, 0.0722718611359596252, 0.0953074842691421509,
    0.0033465356100350618, 0.0085681248456239700, 0.0168073754757642746, 0.0284260381013154984, 0.0437350422143936157, 0.0630100294947624207, 0.0865004658699035645, 0.1144353821873664856,
    0.0036765069235116243, 0.0097212176769971848, 0.0193823613226413727, 0.0331047736108303070, 0.0512694679200649261, 0.0742135792970657349, 0.1022417470812797546, 0.1356333643198013306,
    0.0040247170254588127, 0.0109600936993956566, 0.0221738833934068680, 0.0382043756544589996, 0.0595112405717372894, 0.0865004658699035645, 0.1195384487509727478, 0.1589608639478683472,
    0.0043914420530200005, 0.0122864870354533195, 0.0251868572086095810, 0.0437350422143936157, 0.0684781819581985474, 0.0998987406492233276, 0.1384316533803939819, 0.1844750344753265381,
    0.0047769532538950443, 0.0137020805850625038, 0.0284260381013154984, 0.0497065745294094086, 0.0781874284148216248, 0.1144353821873664856, 0.1589608639478683472, 0.2122307866811752319,
    0.0051815169863402843, 0.0152085144072771072, 0.0318960398435592651, 0.0561284944415092468, 0.0886556059122085571, 0.1301365196704864502, 0.1811642944812774658, 0.2422811985015869141,
    0.0056053916923701763, 0.0168073754757642746, 0.0356013253331184387, 0.0630100294947624207, 0.0998987406492233276, 0.1470272988080978394, 0.2050787657499313354, 0.2746773660182952881,
    0.0060488325543701649, 0.0185002181679010391, 0.0395462475717067719, 0.0703601092100143433, 0.1119324341416358948, 0.1651322394609451294, 0.2307400703430175781, 0.3094689548015594482,
    0.0065120910294353962, 0.0202885624021291733, 0.0437350422143936157, 0.0781874284148216248, 0.1247718632221221924, 0.1844750344753265381, 0.2581829130649566650, 0.3467040956020355225,
    0.0069954101927578449, 0.0221738833934068680, 0.0481718331575393677, 0.0865004658699035645, 0.1384316533803939819, 0.2050787657499313354, 0.2874408960342407227, 0.3864295184612274170,
    0.0074990317225456238, 0.0241576302796602249, 0.0528606548905372620, 0.0953074842691421509, 0.1529261767864227295, 0.2269658893346786499, 0.3185468316078186035, 0.4286905527114868164,
    0.0080231921747326851, 0.0262412223964929581, 0.0578054338693618774, 0.1046164929866790771, 0.1682694554328918457, 0.2501583695411682129, 0.3515326976776123047, 0.4735315442085266113,
    0.0085681248456239700, 0.0284260381013154984, 0.0630100294947624207, 0.1144353821873664856, 0.1844750344753265381, 0.2746773660182952881, 0.3864295184612274170, 0.5209956765174865723,
    0.0091340569779276848, 0.0307134501636028290, 0.0684781819581985474, 0.1247718632221221924, 0.2015562951564788818, 0.3005438446998596191, 0.4232677519321441650, 0.5711250305175781250,
    0.0097212176769971848, 0.0331047736108303070, 0.0742135792970657349, 0.1356333643198013306, 0.2195262312889099121, 0.3277781307697296143, 0.4620770514011383057, 0.6239605545997619629,
    0.0103298230096697807, 0.0356013253331184387, 0.0802198275923728943, 0.1470272988080978394, 0.2383976578712463379, 0.3564002513885498047, 0.5028865933418273926, 0.6795426011085510254,
    0.0109600936993956566, 0.0382043756544589996, 0.0865004658699035645, 0.1589608639478683472, 0.2581829130649566650, 0.3864295184612274170, 0.5457246899604797363, 0.7379106879234313965,
    0.0116122448816895485, 0.0409152098000049591, 0.0930589810013771057, 0.1714411526918411255, 0.2788943350315093994, 0.4178851544857025146, 0.5906190276145935059, 0.7991029620170593262,
    0.0122864870354533195, 0.0437350422143936157, 0.0998987406492233276, 0.1844750344753265381, 0.3005438446998596191, 0.4507858455181121826, 0.6375970244407653809, 0.8631573915481567383,
    0.0129830306395888329, 0.0466650947928428650, 0.1070231124758720398, 0.1980693489313125610, 0.3231432437896728516, 0.4851499795913696289, 0.6866854429244995117, 0.9301111698150634766,
    0.0137020805850625038, 0.0497065745294094086, 0.1144353821873664856, 0.2122307866811752319, 0.3467040956020355225, 0.5209956765174865723, 0.7379106879234313965, 1.0000000000000000000
};

static inline uint8_t fast_linear_to_srgb(float x)
{
    return uchar_clamp_ff(linear_to_srgb(x));

//    // Gamma correction
//    // http://www.4p8.com/eric.brasseur/gamma.html#formulas
//    if (x < 0.0f)
//        return 0;
//    if (x > 1.0f)
//        return 255.0f;
//    float r = 255.0f * fasterpow(x, 1.0f / 2.2f);
//    // return 255.0f * (float)pow(clr, 1.0f / 2.2f);
//    // printf("Linear %f to srgb %f\n", x, r);
//    return r;
}


void jpeg_idct_downscale_wrap_islow_fast(j_decompress_ptr cinfo, jpeg_component_info * compptr, JCOEFPTR coef_block,
                                    JSAMPARRAY output_buf, JDIMENSION output_col)
{

    JSAMPLE intermediate[DCTSIZE2];
    JSAMPROW rows[DCTSIZE];
    JSAMPROW outptr;
    // JSAMPLE * range_limit = cinfo->sample_range_limit;
    int i, ctr, ctr_x;

    for (i = 0; i < DCTSIZE; i++)
        rows[i] = &intermediate[i * DCTSIZE];

    jpeg_idct_islow(cinfo, compptr, coef_block, &rows[0], 0);

#if JPEG_LIB_VERSION >= 70
    int scaled = compptr->DCT_h_scaled_size;
#else
    int scaled = compptr->DCT_scaled_size;
#endif

    //Linearize
    float linearized[DCTSIZE2];
    for (i = 0; i < DCTSIZE2; i++)
        linearized[i] = lut_srgb_to_linear[intermediate[i]];


    //Scale and transpose
    float scaled_h[DCTSIZE2];
    for (int row = 0; row < DCTSIZE; row++) {
        for (int to = 0; to < scaled; to++) {
            const float * weights = weights_by_target[scaled] + DCTSIZE * to;
            float sum = 0;
            for (int from = 0; from < DCTSIZE; from++) {
                sum += weights[from] * linearized[row * DCTSIZE + from];
            }
            scaled_h[to * DCTSIZE + row] = sum;
        }
    }
    //Scale and transpose again
    float scaled_final[DCTSIZE2];
    for (int row = 0; row < scaled; row++) {
        for (int to = 0; to < scaled; to++) {
            const float * weights = weights_by_target[scaled] + DCTSIZE * to;
            float sum = 0;
            for (int from = 0; from < DCTSIZE; from++) {
                sum += weights[from] * scaled_h[row * DCTSIZE + from];
            }
            scaled_final[to * scaled + row] = sum;
        }
    }

    // int input_pixels_window =  8 / scaled;
    int target_size = scaled;
    for (ctr = 0; ctr < target_size; ctr++) {
        outptr = output_buf[ctr] + output_col;
        for (ctr_x = 0; ctr_x < target_size; ctr_x++) {
            outptr[ctr_x] = fast_linear_to_srgb(scaled_final[ctr_x + ctr * target_size]);
        }
    }
}
