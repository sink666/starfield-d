import std.stdio;
import std.random;
import std.math;
import bindbc.sdl;

//
// begin variables, enums, etc
//

enum int WIDTH = 800;
enum int HEIGHT = 600;
enum int NUM_STARS = 300;
enum int FOV = 75;
enum int SPEED = 30;
static uint[4] palette = [ 0x00000000, 0x00666666, 0x00A8A8A8, 0x00FFFFFF];
enum Brightness { OFF, DIM, HALF, FULL }
static P_Screen midp = P_Screen(WIDTH / 2, HEIGHT / 2);

static SDL_Rect targ_rect = { 0, 0, WIDTH, HEIGHT };
SDL_Window *win_ptr;
SDL_Texture *framebuffer_ptr;
SDL_Renderer *renderer_ptr;
string init_errMsg;

uint[WIDTH * HEIGHT] pixel_buffer;
int buf_pitch = (WIDTH * uint.sizeof);
int buf_stride = WIDTH;

//
// begin structs
//

struct P_World 
{ 
    double x, y, z;
    this(double a, double b, double c)
    {
        x = a; y = b; z = c;
    }
}

struct P_Screen 
{
    int x, y; 
    this(int a, int b)
    {
        x = a; y = b;
    }
}

struct Stars
{
    P_World[] star;
    double[] star_zvel;

    this(int nstars)
    {
        star.length = nstars;
        star_zvel.length = nstars;

        foreach(ref s; star)
        {
            s = P_World(uniform(-1.0f, 1.0f), uniform(-1.0f, 1.0f), uniform(-1.0f, 0.0000001f));
        }

        foreach (ref sv; star_zvel)
        {
            sv = uniform(0.0003f, 0.0019f);
        }
    }
}

//
// begin init, main loop functions
//

bool doSDLInit()
{
    if(SDL_Init(SDL_INIT_VIDEO|SDL_INIT_TIMER) == -1)
    {
        init_errMsg = "failed to initialize SDL2";
        goto init_err;
    }

    win_ptr = SDL_CreateWindow("starfield", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 
        WIDTH, HEIGHT, SDL_WINDOW_ALLOW_HIGHDPI);
    if(win_ptr is null)
    {
        init_errMsg = "failed to create window";
        goto init_err;
    }

    renderer_ptr = SDL_CreateRenderer(win_ptr, -1, SDL_RENDERER_TARGETTEXTURE);
    if(renderer_ptr is null)
    {
        init_errMsg = "failed to create SDL renderer";
        goto init_err;
    }

    framebuffer_ptr = SDL_CreateTexture(renderer_ptr, SDL_PIXELFORMAT_RGBA32, 
        SDL_TEXTUREACCESS_TARGET, WIDTH, HEIGHT);
    if(framebuffer_ptr is null)
    {
        init_errMsg = "failed to create framebuffer";
        goto init_err;
    }

    // scaling setup to deal with high dpi
    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "linear");
    SDL_RenderSetLogicalSize(renderer_ptr, WIDTH, HEIGHT);

    return true;

init_err:
    return false;
}

void doShutdown()
{
    SDL_DestroyWindow(win_ptr);
    SDL_DestroyTexture(framebuffer_ptr);
    SDL_DestroyRenderer(renderer_ptr);

    SDL_QuitSubSystem(SDL_INIT_VIDEO|SDL_INIT_TIMER);
    SDL_Quit();
}

bool checkQuit(SDL_Event *ev_ptr)
{
    SDL_PollEvent(ev_ptr);

    if((ev_ptr.key.keysym.scancode == SDL_SCANCODE_ESCAPE) || 
        (ev_ptr.key.keysym.scancode == SDL_SCANCODE_Q) ||
        (ev_ptr.type == SDL_QUIT)) {
        return true;
    }

    return false;
}

//
// rendering and effects functions
//

void change_pixel(int x, int y, uint color)
{
    int index = (buf_stride * x) + y;

    if( index < pixel_buffer.length)
        pixel_buffer[index] = color;
}

void draw_square(P_Screen pos, int lw, Brightness b)
{
    int targ_y = pos.y + lw;
    int targ_x = pos.x + lw;

    for(int j = pos.y; j < targ_y; ++j)
    {   
        for(int k = pos.x; k < targ_x; ++k)
        {
            change_pixel(j, k, palette[b]);
        }
    }
}

void doEffect(Stars *s_ref)
{
    // clear the buffer
    foreach(ref p; pixel_buffer)
        p = palette[Brightness.OFF];

    // move stars along z axis, reset if they reach 0
    for(int i = 0; i < s_ref.star.length; ++i)
    {
        s_ref.star[i].z += s_ref.star_zvel[i];

        if(s_ref.star[i].z >= 0) // reset if we get close enough
        {
            s_ref.star[i] = P_World(uniform(-1.0f, 1.0f), uniform(-1.0f, 1.0f), uniform(-1.0f, 0.0000001f));
            s_ref.star_zvel[i] = uniform(0.0003f, 0.0019f);
        }
    }

    // put a pixel on the canvas
    foreach(size_t i, ref wp; s_ref.star)
    {
        double half_FOV = atan((FOV * (PI / 180)));
        Brightness b = Brightness.OFF;

        P_Screen sp = P_Screen(
            cast(int)((wp.x / (wp.z * half_FOV)) * midp.x) + midp.x,
            cast(int)((wp.y / (wp.z * half_FOV)) * midp.y) + midp.y
        );

        if(wp.z > -0.3)
        {
            b = Brightness.FULL;
        }
        else if(wp.z > -0.6)
        {
            b = Brightness.HALF;
        }
        else if(wp.z > -0.9)
        {
            b = Brightness.DIM;
        }

        // reset if oob
        if(sp.x < 0 || sp.x >= WIDTH || (sp.y < 0 || sp.y >= HEIGHT))
        {
            s_ref.star[i] = P_World(uniform(-1.0f, 1.0f), uniform(-1.0f, 1.0f), uniform(-1.0f, 0.0000001f));
            s_ref.star_zvel[i] = uniform(0.0003f, 0.0019f);
        } 
        else 
        {
            draw_square(sp, 1, b);
        }
    }
}

void doRender()
{
    SDL_UpdateTexture(framebuffer_ptr, null, &pixel_buffer, buf_pitch);
    SDL_RenderCopy(renderer_ptr, framebuffer_ptr, null, null);
    SDL_RenderPresent(renderer_ptr);
}

//
// main
//

int main()
{
    SDL_Event ev;
    Stars s = Stars(NUM_STARS);

    if(doSDLInit() is false)
    {
        doShutdown();
        writeln("error during init: ", init_errMsg);
        return 1;
    }

    while(1)
    {
        if(checkQuit(&ev)) 
            break;

        doEffect(&s);
        doRender();
        SDL_Delay(SPEED);
    }

    doShutdown();
    return 0;
}