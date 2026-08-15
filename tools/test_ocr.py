import winrt.windows.media.ocr as ocr
import winrt.windows.globalization as glob
import winrt.windows.graphics.imaging as imaging
import winrt.windows.storage.streams as streams
import asyncio
import os

async def ocr_image(engine, path):
    with open(path, 'rb') as f:
        data = f.read()
    mem_stream = streams.InMemoryRandomAccessStream()
    writer = streams.DataWriter(mem_stream)
    writer.write_bytes(data)
    await writer.store_async()
    await writer.flush_async()
    mem_stream.seek(0)
    decoder = await imaging.BitmapDecoder.create_async(mem_stream)
    software_bitmap = await decoder.get_software_bitmap_async()
    res = await engine.recognize_async(software_bitmap)
    return res.text

async def main():
    engine = ocr.OcrEngine.try_create_from_user_profile_languages()
    for folder in ['admin_images', 'owner_images', 'rider_images']:
        print('==================== ' + folder + ' ====================')
        for f in sorted(os.listdir(folder)):
            p = os.path.join(folder, f)
            text = await ocr_image(engine, p)
            clean_text = " ".join(text.split())
            print(f"[{f}] -> {clean_text[:200]}")

if __name__ == '__main__':
    asyncio.run(main())
